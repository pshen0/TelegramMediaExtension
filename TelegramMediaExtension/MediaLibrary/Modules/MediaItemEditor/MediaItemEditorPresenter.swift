import Foundation

protocol MediaItemEditorDisplayLogic: AnyObject {
    func displayContent(_ viewModel: MediaItemEditorModel.Content.ViewModel)
    func displayError(_ viewModel: MediaItemEditorModel.ErrorAlert.ViewModel)
}

protocol MediaItemEditorPresentationLogic: AnyObject {
    func presentContent(_ response: MediaItemEditorModel.Content.Response)
    func presentError(title: String, message: String?)
}

final class MediaItemEditorPresenter: MediaItemEditorPresentationLogic {
    weak var view: MediaItemEditorDisplayLogic?

    func presentContent(_ response: MediaItemEditorModel.Content.Response) {
        view?.displayContent(.init(mode: response.mode, item: response.item, navigationTitle: response.navigationTitle, canDelete: response.canDelete))
    }

    func presentError(title: String, message: String?) {
        view?.displayError(.init(title: title, message: message))
    }
}

