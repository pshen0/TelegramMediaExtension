import Foundation

protocol MediaCatalogSearchDisplayLogic: AnyObject {
    func displayList(_ viewModel: MediaCatalogSearchModel.List.ViewModel)
}

protocol MediaCatalogSearchPresentationLogic: AnyObject {
    func presentList(_ response: MediaCatalogSearchModel.List.Response)
}

final class MediaCatalogSearchPresenter: MediaCatalogSearchPresentationLogic {
    weak var view: MediaCatalogSearchDisplayLogic?

    func presentList(_ response: MediaCatalogSearchModel.List.Response) {
        view?.displayList(.init(rows: response.rows))
    }
}

