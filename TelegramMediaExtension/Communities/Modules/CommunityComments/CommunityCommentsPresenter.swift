import Foundation

protocol CommunityCommentsDisplayLogic: AnyObject {
    func displayComments(_ viewModel: CommunityCommentsModel.CommentsList.ViewModel)
}

protocol CommunityCommentsPresentationLogic: AnyObject {
    func presentComments(_ response: CommunityCommentsModel.CommentsList.Response)
}

final class CommunityCommentsPresenter: CommunityCommentsPresentationLogic {

    weak var view: CommunityCommentsDisplayLogic?

    func presentComments(_ response: CommunityCommentsModel.CommentsList.Response) {
        view?.displayComments(
            CommunityCommentsModel.CommentsList.ViewModel(
                comments: response.comments,
                scrollAnimated: response.scrollAnimated
            )
        )
    }
}
