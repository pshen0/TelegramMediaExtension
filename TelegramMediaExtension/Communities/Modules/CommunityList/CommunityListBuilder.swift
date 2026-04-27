import UIKit

enum CommunityListBuilder {

    static func build() -> CommunityListViewController {
        let presenter = CommunityListPresenter()
        let interactor = CommunityListInteractor(presenter: presenter)
        let view = CommunityListViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}
