import Combine
import Foundation

protocol CommunityListBusinessLogic: AnyObject {
    func viewDidLoad(_ request: CommunityListModel.ViewDidLoad.Request)
    func viewWillAppear()
    func viewWillDisappear()
    func updateSearch(_ request: CommunityListModel.UpdateSearch.Request)
    func deleteCommunity(_ request: CommunityListModel.DeleteCommunity.Request)
    func createCommunity(_ request: CommunityListModel.CreateCommunity.Request)
    func selectRow(_ request: CommunityListModel.SelectRow.Request)
}

protocol CommunityListRoutingLogic: AnyObject {
    func routeToChat(communityId: UUID)
}

final class CommunityListInteractor: CommunityListBusinessLogic {

    private let presenter: CommunityListPresentationLogic
    private let store = CommunityStore.shared
    private let backend = BackendClient.shared
    private let mediaStore = MediaLibraryStore.shared

    weak var router: CommunityListRoutingLogic?

    private var cancellables = Set<AnyCancellable>()
    private var searchQuery: String = ""
    private var discoverResults: [CommunityChat] = []
    private var realtimeTask: Task<Void, Never>?

    init(presenter: CommunityListPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: CommunityListModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        bindStores()
        pushListToPresenter()
        Task { [weak self] in
            await self?.store.refreshCommunities()
        }
    }

    func viewWillAppear() {
        startRealtime()
    }

    func viewWillDisappear() {
        stopRealtime()
    }

    private func startRealtime() {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.store.longPollMyCommunities()
                } catch {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    private func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func updateSearch(_ request: CommunityListModel.UpdateSearch.Request) {
        searchQuery = request.query
        pushListToPresenter()
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else {
            discoverResults = []
            pushListToPresenter()
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let found = try await backend.searchCommunities(query: trimmed, limit: 20)
                let myIds = Set(store.communities.map(\.id))
                self.discoverResults = found.filter { !myIds.contains($0.id) }
            } catch {
                self.discoverResults = []
            }
            self.pushListToPresenter()
        }
    }

    func deleteCommunity(_ request: CommunityListModel.DeleteCommunity.Request) {
        store.deleteCommunity(id: request.id)
    }

    func createCommunity(_ request: CommunityListModel.CreateCommunity.Request) {
        let c = store.createCommunity(title: request.title)
        router?.routeToChat(communityId: c.id)
    }

    func selectRow(_ request: CommunityListModel.SelectRow.Request) {
        switch request.row.kind {
        case .member:
            router?.routeToChat(communityId: request.row.community.id)
        case .discover:
            let id = request.row.community.id
            Task { [weak self] in
                guard let self else { return }
                do {
                    _ = try await backend.joinCommunity(communityId: id)
                    await store.refreshCommunities()
                    await store.refreshMyMembershipRole(communityId: id)
                    await MainActor.run {
                        self.searchQuery = ""
                        self.discoverResults = []
                        self.pushListToPresenter()
                    }
                    await MainActor.run {
                        self.router?.routeToChat(communityId: id)
                    }
                } catch {
                    //
                }
            }
        }
    }

    private func bindStores() {
        store.$communities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushListToPresenter()
            }
            .store(in: &cancellables)

        store.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushListToPresenter()
            }
            .store(in: &cancellables)
    }

    private func filteredCommunities() -> [CommunityChat] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return store.communities
        }
        let q = trimmed.lowercased()
        return store.communities.filter { c in
            if c.title.lowercased().contains(q) { return true }
            let preview = store.listPreviewText(for: c.id)
            return preview.lowercased().contains(q)
        }
    }

    private func pushListToPresenter() {
        let chats = filteredCommunities()
        var rows: [CommunityListModel.List.Row] = chats.map { chat in
            let preview = store.listPreviewText(for: chat.id)
            let last = store.lastMessage(for: chat.id)
            let timeText = last.map { Self.formatListTime($0.createdAt) } ?? ""
            let previewHidden = last.map { shouldHidePreviewForSpoiler(lastMessage: $0) } ?? false
            return CommunityListModel.List.Row(
                community: chat,
                preview: preview,
                timeText: timeText,
                kind: .member,
                previewIsHiddenSpoiler: previewHidden
            )
        }

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !discoverResults.isEmpty {
            let discoverRows = discoverResults.map { c in
                CommunityListModel.List.Row(
                    community: c,
                    preview: "Нажмите, чтобы подписаться",
                    timeText: "",
                    kind: .discover,
                    previewIsHiddenSpoiler: false
                )
            }
            rows.append(contentsOf: discoverRows)
        }
        presenter.presentCommunityList(CommunityListModel.List.Response(rows: rows))
    }

    private func shouldHidePreviewForSpoiler(lastMessage: CommunityMessage) -> Bool {
        guard lastMessage.kind == .post else { return false }
        guard !lastMessage.spoilerTags.isEmpty else { return false }

        for tag in lastMessage.spoilerTags {
            guard tag.catalogSourceID.hasPrefix("tmdb-") else { continue }
            guard let item = mediaStore.item(catalogSourceID: tag.catalogSourceID) else { continue }
            guard item.spoilersProtectionEnabled else { continue }

            switch (tag.kind, item.kind) {
            case (.filmTimecode, .film):
                let current = max(0, item.progress.current ?? 0)
                let tm = max(0, tag.timeMinutes ?? 0)
                if tm > current { return true }
            case (.seriesEpisode, .series):
                let curSeason = max(1, item.progress.season ?? 1)
                let curEpisode = max(0, item.progress.current ?? 0)
                let s = max(1, tag.season ?? 1)
                let e = max(0, tag.episode ?? 0)
                if s > curSeason { return true }
                if s == curSeason, e > curEpisode { return true }
            default:
                break
            }
        }
        return false
    }

    private static func formatListTime(_ date: Date) -> String {
        let cal = Calendar.current
        let fTime = DateFormatter()
        fTime.locale = Locale(identifier: "ru_RU")
        fTime.dateFormat = "HH:mm"
        if cal.isDateInToday(date) {
            return fTime.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            return "Вчера"
        }
        let fDay = DateFormatter()
        fDay.locale = Locale(identifier: "ru_RU")
        if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            fDay.dateFormat = "d MMM"
        } else {
            fDay.dateFormat = "d.MM.yy"
        }
        return fDay.string(from: date)
    }
}
