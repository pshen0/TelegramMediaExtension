import Foundation

protocol MediaLibraryGridBusinessLogic: AnyObject {
    func viewDidLoad(_ request: MediaLibraryGridModel.ViewDidLoad.Request)
    func viewWillAppear(_ request: MediaLibraryGridModel.ViewWillAppear.Request)
    func selectItem(_ request: MediaLibraryGridModel.SelectItem.Request)
}

protocol MediaLibraryGridRoutingLogic: AnyObject {
    func routeToItemDetail(item: MediaItem)
}

final class MediaLibraryGridInteractor: MediaLibraryGridBusinessLogic {
    private let presenter: MediaLibraryGridPresentationLogic
    weak var router: MediaLibraryGridRoutingLogic?

    var itemsProvider: (() -> [MediaItem])?

    init(presenter: MediaLibraryGridPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: MediaLibraryGridModel.ViewDidLoad.Request) {
        push()
    }

    func viewWillAppear(_ request: MediaLibraryGridModel.ViewWillAppear.Request) {
        push()
    }

    func selectItem(_ request: MediaLibraryGridModel.SelectItem.Request) {
        let items = itemsProvider?() ?? []
        guard request.index >= 0, request.index < items.count else { return }
        router?.routeToItemDetail(item: items[request.index])
    }

    private func push() {
        presenter.presentList(.init(items: itemsProvider?() ?? []))
    }
}

