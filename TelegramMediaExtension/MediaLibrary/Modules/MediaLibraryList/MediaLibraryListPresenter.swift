import Foundation

protocol MediaLibraryListDisplayLogic: AnyObject {
    func displayList(_ viewModel: MediaLibraryListModel.List.ViewModel)
}

protocol MediaLibraryListPresentationLogic: AnyObject {
    func presentList(_ response: MediaLibraryListModel.List.Response)
}

final class MediaLibraryListPresenter: MediaLibraryListPresentationLogic {
    weak var view: MediaLibraryListDisplayLogic?

    func presentList(_ response: MediaLibraryListModel.List.Response) {
        let mode: MediaLibraryEmptyStateView.Mode = response.isLibraryEmpty ? .libraryEmpty : .filteredEmpty
        view?.displayList(.init(items: response.items, isEmpty: response.isEmpty, emptyMode: mode))
    }
}

