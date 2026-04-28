import Combine
import Foundation

protocol CommunityChatBusinessLogic: AnyObject {
    func viewDidLoad(_ request: CommunityChatModel.ViewDidLoad.Request)
    func viewWillAppear()
    func viewWillDisappear()
    func sendMessage(_ request: CommunityChatModel.SendMessage.Request)
    func spoilerDecision(for message: CommunityMessage) -> CommunityChatModel.SpoilerDecision?
    func announcementIsSaved(for message: CommunityMessage) -> Bool
    func saveAnnouncementFromMessage(_ message: CommunityMessage)
}

protocol CommunityChatRoutingLogic: AnyObject {
    func routeToEditCommunityProfile()
    func routeToNewAnnouncement()
    func routeToComments(message: CommunityMessage)
    func presentSafari(url: URL)
    func openExternalURL(_ url: URL)
}

final class CommunityChatInteractor: CommunityChatBusinessLogic {

    let communityId: UUID

    private let presenter: CommunityChatPresentationLogic
    private let store = CommunityStore.shared
    private let mediaStore = MediaLibraryStore.shared

    weak var router: CommunityChatRoutingLogic?

    private var cancellables = Set<AnyCancellable>()
    private var didPresentInitialMessages = false
    private var messagesTask: Task<Void, Never>?
    private var metaTask: Task<Void, Never>?

    init(presenter: CommunityChatPresentationLogic, communityId: UUID) {
        self.presenter = presenter
        self.communityId = communityId
    }

    func viewDidLoad(_ request: CommunityChatModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        bindStores()
        pushTitleToPresenter()
        Task { [weak self] in
            guard let self else { return }
            await self.store.refreshMessages(communityId: self.communityId)
            await self.store.refreshMyMembershipRole(communityId: self.communityId)
            self.pushInputAvailabilityToPresenter()
        }
    }

    func viewWillAppear() {
        startRealtime()
    }

    func viewWillDisappear() {
        stopRealtime()
    }

    private func startRealtime() {
        guard messagesTask == nil, metaTask == nil else { return }

        messagesTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.store.longPollNewMessages(communityId: self.communityId)
                } catch {
                    // Backoff on network errors.
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }

        metaTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await self.store.longPollCommunityMeta(communityId: self.communityId)
                } catch {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    private func stopRealtime() {
        messagesTask?.cancel()
        metaTask?.cancel()
        messagesTask = nil
        metaTask = nil
    }

    func sendMessage(_ request: CommunityChatModel.SendMessage.Request) {
        store.addPost(communityId: communityId, text: request.text, spoilerTags: request.spoilerTags)
    }

    func announcementIsSaved(for message: CommunityMessage) -> Bool {
        store.savedAnnouncements.contains(where: { $0.sourceMessageId == message.id })
    }

    func saveAnnouncementFromMessage(_ message: CommunityMessage) {
        store.saveAnnouncementFromMessage(message)
    }

    func spoilerDecision(for message: CommunityMessage) -> CommunityChatModel.SpoilerDecision? {
        guard message.kind == .post else { return nil }
        guard !message.spoilerTags.isEmpty else { return nil }

        for tag in message.spoilerTags {
            guard tag.catalogSourceID.hasPrefix("tmdb-") else { continue }
            guard let item = mediaStore.item(catalogSourceID: tag.catalogSourceID) else { continue }
            guard item.spoilersProtectionEnabled else { continue }

            if tagIsAheadOfProgress(tag: tag, item: item) {
                return CommunityChatModel.SpoilerDecision(
                    title: tag.mediaTitle,
                    subtitle: spoilerSubtitle(for: tag),
                    messageId: message.id
                )
            }
        }
        return nil
    }

    private func bindStores() {
        store.$communities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushTitleToPresenter()
            }
            .store(in: &cancellables)

        store.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let animated = self.didPresentInitialMessages
                self.didPresentInitialMessages = true
                self.pushMessagesToPresenter(scrollAnimated: animated)
            }
            .store(in: &cancellables)

        store.$membershipRoles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushInputAvailabilityToPresenter()
            }
            .store(in: &cancellables)

        mediaStore.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.presenter.notifyDependentStoresChanged()
            }
            .store(in: &cancellables)

        store.$savedAnnouncements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.presenter.notifyDependentStoresChanged()
            }
            .store(in: &cancellables)
    }

    private func pushMessagesToPresenter(scrollAnimated: Bool) {
        let msgs = store.messages(for: communityId)
        presenter.presentMessages(
            CommunityChatModel.Messages.Response(messages: msgs, scrollAnimated: scrollAnimated)
        )
    }

    private func pushTitleToPresenter() {
        let title = store.communities.first(where: { $0.id == communityId })?.title ?? "Сообщество"
        presenter.presentCommunityTitle(CommunityChatModel.NavigationTitle.Response(title: title))
    }

    private func pushInputAvailabilityToPresenter() {
        presenter.presentInputAvailability(
            CommunityChatModel.InputAvailability.Response(canSendMessages: store.canSendMessages(in: communityId))
        )
    }

    private func tagIsAheadOfProgress(tag: CommunitySpoilerTag, item: MediaItem) -> Bool {
        switch (tag.kind, item.kind) {
        case (.filmTimecode, .film):
            let current = max(0, item.progress.current ?? 0)
            let tm = max(0, tag.timeMinutes ?? 0)
            return tm > current
        case (.seriesEpisode, .series):
            let curSeason = max(1, item.progress.season ?? 1)
            let curEpisode = max(0, item.progress.current ?? 0)
            let s = max(1, tag.season ?? 1)
            let e = max(0, tag.episode ?? 0)
            if s > curSeason { return true }
            if s < curSeason { return false }
            return e > curEpisode
        default:
            return false
        }
    }

    private func spoilerSubtitle(for tag: CommunitySpoilerTag) -> String {
        switch tag.kind {
        case .seriesEpisode:
            let s = max(1, tag.season ?? 1)
            let e = max(1, tag.episode ?? 1)
            return "Сезон \(s), эпизод \(e)"
        case .filmTimecode:
            let m = max(0, tag.timeMinutes ?? 0)
            let hh = m / 60
            let mm = m % 60
            return String(format: "Таймкод %02d:%02d", hh, mm)
        }
    }
}
