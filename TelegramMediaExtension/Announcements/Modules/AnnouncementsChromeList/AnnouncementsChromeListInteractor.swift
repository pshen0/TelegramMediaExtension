import Combine
import UIKit

protocol AnnouncementsChromeListBusinessLogic: AnyObject {
    func viewDidLoad(_ request: AnnouncementsChromeListModel.ViewDidLoad.Request)
    func updateSearchQuery(_ request: AnnouncementsChromeListModel.UpdateSearchQuery.Request)
    func deleteAnnouncement(_ request: AnnouncementsChromeListModel.DeleteAnnouncement.Request)
    func selectAnnouncement(_ request: AnnouncementsChromeListModel.SelectAnnouncement.Request)
    func viewWillAppear()
}

protocol AnnouncementsChromeListRoutingLogic: AnyObject {
    func routeToDetail(_ announcement: SavedAnnouncement)
}

final class AnnouncementsChromeListInteractor: AnnouncementsChromeListBusinessLogic {

    private let presenter: AnnouncementsChromeListPresentationLogic
    private let store = CommunityStore.shared
    private let searchScope: AnnouncementsChromeListModel.SearchScope

    weak var router: AnnouncementsChromeListRoutingLogic?

    private var cancellables = Set<AnyCancellable>()
    private var query: String = ""

    init(presenter: AnnouncementsChromeListPresentationLogic, searchScope: AnnouncementsChromeListModel.SearchScope) {
        self.presenter = presenter
        self.searchScope = searchScope
    }

    func viewDidLoad(_ request: AnnouncementsChromeListModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        bindStore()
        applyFilterAndPresent()
    }

    func viewWillAppear() {
        store.loadIfNeeded()
        applyFilterAndPresent()
    }

    func updateSearchQuery(_ request: AnnouncementsChromeListModel.UpdateSearchQuery.Request) {
        query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilterAndPresent()
    }

    func deleteAnnouncement(_ request: AnnouncementsChromeListModel.DeleteAnnouncement.Request) {
        store.deleteSavedAnnouncement(id: request.id)
        applyFilterAndPresent()
    }

    func selectAnnouncement(_ request: AnnouncementsChromeListModel.SelectAnnouncement.Request) {
        guard let a = store.savedAnnouncements.first(where: { $0.id == request.id }) else { return }
        router?.routeToDetail(a)
    }

    private func bindStore() {
        store.$savedAnnouncements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilterAndPresent()
            }
            .store(in: &cancellables)
    }

    private func applyFilterAndPresent() {
        let q = query.lowercased()
        let base = store.savedAnnouncements
        let filtered: [SavedAnnouncement]
        if q.isEmpty {
            filtered = base
        } else {
            switch searchScope {
            case .titleOnly:
                filtered = base.filter { $0.title.lowercased().contains(q) }
            case .titleDetailsLink:
                filtered = base.filter { a in
                    if a.title.lowercased().contains(q) { return true }
                    if (a.details ?? "").lowercased().contains(q) { return true }
                    if (a.linkURL ?? "").lowercased().contains(q) { return true }
                    return false
                }
            }
        }
        presenter.presentAnnouncements(AnnouncementsChromeListModel.AnnouncementsChanged.Response(announcements: filtered))
    }
}
