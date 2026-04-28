import Foundation

protocol MediaLibraryGridDisplayLogic: AnyObject {
    func displayList(_ viewModel: MediaLibraryGridModel.List.ViewModel)
}

protocol MediaLibraryGridPresentationLogic: AnyObject {
    func presentList(_ response: MediaLibraryGridModel.List.Response)
}

final class MediaLibraryGridPresenter: MediaLibraryGridPresentationLogic {
    weak var view: MediaLibraryGridDisplayLogic?

    func presentList(_ response: MediaLibraryGridModel.List.Response) {
        view?.displayList(.init(items: response.items))
    }
}

