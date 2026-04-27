import UIKit

enum CommunityChatBuilder {

    static func build(communityId: UUID) -> CommunityChatViewController {
        let presenter = CommunityChatPresenter()
        let interactor = CommunityChatInteractor(presenter: presenter, communityId: communityId)
        let view = CommunityChatViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}
