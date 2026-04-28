import UIKit

enum MediaLibraryGridBuilder {
    static func build(itemsProvider: @escaping () -> [MediaItem]) -> MediaLibraryGridViewController {
        let presenter = MediaLibraryGridPresenter()
        let interactor = MediaLibraryGridInteractor(presenter: presenter)
        interactor.itemsProvider = itemsProvider
        let view = MediaLibraryGridViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}

