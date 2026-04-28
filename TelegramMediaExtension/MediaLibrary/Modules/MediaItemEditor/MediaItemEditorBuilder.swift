import UIKit

enum MediaItemEditorBuilder {
    static func build(mode: MediaItemEditorViewController.Mode, onSave: @escaping (MediaItem) -> Void) -> MediaItemEditorViewController {
        let presenter = MediaItemEditorPresenter()
        let interactor = MediaItemEditorInteractor(presenter: presenter)
        let view = MediaItemEditorViewController(interactor: interactor, mode: mode, onSave: onSave)
        presenter.view = view
        interactor.router = view
        return view
    }
}

