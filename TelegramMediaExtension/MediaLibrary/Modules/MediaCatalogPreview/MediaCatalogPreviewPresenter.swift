import Foundation

protocol MediaCatalogPreviewDisplayLogic: AnyObject {
    func displayContent(_ viewModel: MediaCatalogPreviewModel.Content.ViewModel)
}

protocol MediaCatalogPreviewPresentationLogic: AnyObject {
    func presentContent(_ response: MediaCatalogPreviewModel.Content.Response)
}

final class MediaCatalogPreviewPresenter: MediaCatalogPreviewPresentationLogic {
    weak var view: MediaCatalogPreviewDisplayLogic?

    func presentContent(_ response: MediaCatalogPreviewModel.Content.Response) {
        view?.displayContent(
            .init(
                title: response.title,
                kindTitle: response.kindTitle,
                metaText: response.metaText,
                synopsisText: response.synopsisText,
                hintText: response.hintText
            )
        )
    }
}

