import UIKit

enum MediaLibraryListBuilder {
    static func build() -> MediaLibraryListViewController {
        let presenter = MediaLibraryListPresenter()
        let interactor = MediaLibraryListInteractor(presenter: presenter)
        let view = MediaLibraryListViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}

