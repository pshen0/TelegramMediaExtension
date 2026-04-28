import Combine
import Foundation

protocol MediaLibraryListBusinessLogic: AnyObject {
    func viewDidLoad(_ request: MediaLibraryListModel.ViewDidLoad.Request)
    func viewWillAppear(_ request: MediaLibraryListModel.ViewWillAppear.Request)
    func updateSearchQuery(_ request: MediaLibraryListModel.UpdateSearchQuery.Request)
    func clearSearch(_ request: MediaLibraryListModel.ClearSearch.Request)
    func applyTabIndex(_ request: MediaLibraryListModel.ApplyTabIndex.Request)
    func setKindFilter(_ request: MediaLibraryListModel.SetKindFilter.Request)
    func setSort(_ request: MediaLibraryListModel.SetSort.Request)
    func openGrid(_ request: MediaLibraryListModel.OpenGrid.Request)
    func bannerTapped(_ request: MediaLibraryListModel.BannerTapped.Request)
    func addTapped(_ request: MediaLibraryListModel.AddTapped.Request)
    func doneTapped(_ request: MediaLibraryListModel.DoneTapped.Request)
    func deleteItem(_ request: MediaLibraryListModel.DeleteItem.Request)
    func selectItem(_ request: MediaLibraryListModel.SelectItem.Request)
}

protocol MediaLibraryListRoutingLogic: AnyObject {
    func routeToBannerColorPicker()
    func routeToAddFlow()
    func routeToGrid(itemsProvider: @escaping () -> [MediaItem])
    func routeToAnnouncements()
    func routeToItemDetail(item: MediaItem)
    func routeDismiss()
    func routeFocusSearch()
    func routeUpdateOverflowMenu()
}

final class MediaLibraryListInteractor: MediaLibraryListBusinessLogic {
    private let presenter: MediaLibraryListPresentationLogic
    private let store = MediaLibraryStore.shared

    weak var router: MediaLibraryListRoutingLogic?

    private var cancellables = Set<AnyCancellable>()

    private var filteredItems: [MediaItem] = []
    private var query: String = ""
    private var statusFilter: MediaWatchStatus?
    private var kindFilter: MediaItemKind?
    private var favoritesOnly: Bool = false
    private var sort: MediaLibraryListModel.Sort = .updatedDesc

    init(presenter: MediaLibraryListPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: MediaLibraryListModel.ViewDidLoad.Request) {
        bindStore()
        push()
        Task { [weak self] in
            guard let self else { return }
            await self.store.loadIfNeededAsync()
            self.push()
        }
    }

    func viewWillAppear(_ request: MediaLibraryListModel.ViewWillAppear.Request) {
        push()
    }

    func updateSearchQuery(_ request: MediaLibraryListModel.UpdateSearchQuery.Request) {
        query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        push()
    }

    func clearSearch(_ request: MediaLibraryListModel.ClearSearch.Request) {
        query = ""
        push()
    }

    func applyTabIndex(_ request: MediaLibraryListModel.ApplyTabIndex.Request) {
        let index = request.index
        if index <= 0 {
            favoritesOnly = false
            statusFilter = nil
        } else if index == 1 {
            favoritesOnly = true
            statusFilter = nil
        } else {
            favoritesOnly = false
            statusFilter = MediaWatchStatus.allCases[index - 2]
        }
        push()
        router?.routeUpdateOverflowMenu()
    }

    func setKindFilter(_ request: MediaLibraryListModel.SetKindFilter.Request) {
        kindFilter = request.kind
        push()
        router?.routeUpdateOverflowMenu()
    }

    func setSort(_ request: MediaLibraryListModel.SetSort.Request) {
        sort = request.sort
        push()
        router?.routeUpdateOverflowMenu()
    }

    func openGrid(_ request: MediaLibraryListModel.OpenGrid.Request) {
        router?.routeToGrid { [weak self] in
            self?.filteredItems ?? []
        }
    }

    func bannerTapped(_ request: MediaLibraryListModel.BannerTapped.Request) {
        router?.routeToBannerColorPicker()
    }

    func addTapped(_ request: MediaLibraryListModel.AddTapped.Request) {
        router?.routeToAddFlow()
    }

    func doneTapped(_ request: MediaLibraryListModel.DoneTapped.Request) {
        router?.routeDismiss()
    }

    func deleteItem(_ request: MediaLibraryListModel.DeleteItem.Request) {
        store.delete(id: request.id)
    }

    func selectItem(_ request: MediaLibraryListModel.SelectItem.Request) {
        let idx = request.index
        guard idx >= 0, idx < filteredItems.count else { return }
        router?.routeToItemDetail(item: filteredItems[idx])
    }

    private func bindStore() {
        store.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.push()
            }
            .store(in: &cancellables)
    }

    private func push() {
        let items = store.items
        let q = query.lowercased()

        var result = items

        if favoritesOnly {
            result = result.filter(\.isFavorite)
        }

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        if let kindFilter {
            result = result.filter { $0.kind == kindFilter }
        }

        if !q.isEmpty {
            let hashtagQuery: String? = {
                if q.hasPrefix("#") { return String(q.dropFirst()) }
                return nil
            }()

            result = result.filter { item in
                if item.title.lowercased().contains(q) { return true }
                if let hashtagQuery {
                    return item.hashtags.contains(where: { $0.lowercased().contains(hashtagQuery) })
                }
                return item.hashtags.contains(where: { ("#" + $0).lowercased().contains(q) })
            }
        }

        switch sort {
        case .updatedDesc:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .titleAsc:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        filteredItems = result

        let total = store.totalItemCount()
        let noFilters = query.isEmpty && statusFilter == nil && kindFilter == nil && favoritesOnly == false
        let isLibraryEmpty = (total == 0 && noFilters)
        presenter.presentList(.init(items: result, totalCount: total, isEmpty: result.isEmpty, isLibraryEmpty: isLibraryEmpty))
    }
}

