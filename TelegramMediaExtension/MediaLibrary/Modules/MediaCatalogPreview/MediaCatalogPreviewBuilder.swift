import UIKit

enum MediaCatalogPreviewBuilder {
    static func build(candidate: MediaCatalogCandidate) -> MediaCatalogPreviewViewController {
        let presenter = MediaCatalogPreviewPresenter()
        let interactor = MediaCatalogPreviewInteractor(presenter: presenter)
        let view = MediaCatalogPreviewViewController(interactor: interactor, candidate: candidate)
        presenter.view = view
        interactor.router = view
        return view
    }
}

