import UIKit

enum CommunityCommentsBuilder {

    static func build(message: CommunityMessage, threadParentCommentId: UUID? = nil) -> CommunityCommentsViewController {
        let presenter = CommunityCommentsPresenter()
        let interactor = CommunityCommentsInteractor(
            presenter: presenter,
            rootMessage: message,
            threadParentCommentId: threadParentCommentId
        )
        let view = CommunityCommentsViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}
