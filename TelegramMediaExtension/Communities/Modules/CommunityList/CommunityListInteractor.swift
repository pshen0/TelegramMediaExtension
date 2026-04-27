import Combine
import Foundation

protocol CommunityListBusinessLogic: AnyObject {
    func viewDidLoad(_ request: CommunityListModel.ViewDidLoad.Request)
    func updateSearch(_ request: CommunityListModel.UpdateSearch.Request)
    func deleteCommunity(_ request: CommunityListModel.DeleteCommunity.Request)
    func createCommunity(_ request: CommunityListModel.CreateCommunity.Request)
}

protocol CommunityListRoutingLogic: AnyObject {
    func routeToChat(communityId: UUID)
}

final class CommunityListInteractor: CommunityListBusinessLogic {

    private let presenter: CommunityListPresentationLogic
    private let store = CommunityStore.shared

    weak var router: CommunityListRoutingLogic?

    private var cancellables = Set<AnyCancellable>()
    private var searchQuery: String = ""

    init(presenter: CommunityListPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: CommunityListModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        bindStores()
        pushListToPresenter()
    }

    func updateSearch(_ request: CommunityListModel.UpdateSearch.Request) {
        searchQuery = request.query
        pushListToPresenter()
    }

    func deleteCommunity(_ request: CommunityListModel.DeleteCommunity.Request) {
        store.deleteCommunity(id: request.id)
    }

    func createCommunity(_ request: CommunityListModel.CreateCommunity.Request) {
        let c = store.createCommunity(title: request.title)
        router?.routeToChat(communityId: c.id)
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
        let rows: [CommunityListModel.List.Row] = chats.map { chat in
            let preview = store.listPreviewText(for: chat.id)
            let last = store.lastMessage(for: chat.id)
            let timeText = last.map { Self.formatListTime($0.createdAt) } ?? ""
            return CommunityListModel.List.Row(community: chat, preview: preview, timeText: timeText)
        }
        presenter.presentCommunityList(CommunityListModel.List.Response(rows: rows))
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
