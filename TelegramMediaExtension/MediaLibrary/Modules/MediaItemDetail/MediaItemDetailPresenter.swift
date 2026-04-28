import Foundation

protocol MediaItemDetailDisplayLogic: AnyObject {
    func displayContent(_ viewModel: MediaItemDetailModel.Content.ViewModel)
}

protocol MediaItemDetailPresentationLogic: AnyObject {
    func presentContent(_ response: MediaItemDetailModel.Content.Response)
}

final class MediaItemDetailPresenter: MediaItemDetailPresentationLogic {
    weak var view: MediaItemDetailDisplayLogic?

    func presentContent(_ response: MediaItemDetailModel.Content.Response) {
        view?.displayContent(
            .init(
                title: response.title,
                metaText: response.metaText,
                synopsisText: response.synopsisText,
                synopsisIsPlaceholder: response.synopsisIsPlaceholder,
                statusIndex: response.statusIndex,
                progressText: response.progressText,
                notesText: response.notesText,
                tagsText: response.tagsText,
                tagsArePlaceholder: response.tagsArePlaceholder,
                isFavorite: response.item.isFavorite,
                kind: response.item.kind,
                coverFileName: response.item.coverFileName
            )
        )
    }
}

