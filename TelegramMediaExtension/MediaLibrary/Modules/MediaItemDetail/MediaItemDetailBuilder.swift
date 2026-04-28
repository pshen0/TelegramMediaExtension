import UIKit

enum MediaItemDetailBuilder {
    static func build(item: MediaItem) -> MediaItemDetailViewController {
        let presenter = MediaItemDetailPresenter()
        let interactor = MediaItemDetailInteractor(presenter: presenter)
        let view = MediaItemDetailViewController(interactor: interactor, item: item)
        presenter.view = view
        interactor.router = view
        return view
    }
}

