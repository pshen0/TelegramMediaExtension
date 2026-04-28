import UIKit

enum AddToMediaLibraryBuilder {
    static func build() -> AddToMediaLibraryViewController {
        let presenter = AddToMediaLibraryPresenter()
        let interactor = AddToMediaLibraryInteractor(presenter: presenter)
        let view = AddToMediaLibraryViewController(interactor: interactor)
        presenter.view = view
        return view
    }
}

