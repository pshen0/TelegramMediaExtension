import Foundation

protocol CommunityListDisplayLogic: AnyObject {
    func displayCommunityList(_ viewModel: CommunityListModel.List.ViewModel)
}

protocol CommunityListPresentationLogic: AnyObject {
    func presentCommunityList(_ response: CommunityListModel.List.Response)
}

final class CommunityListPresenter: CommunityListPresentationLogic {

    weak var view: CommunityListDisplayLogic?

    func presentCommunityList(_ response: CommunityListModel.List.Response) {
        view?.displayCommunityList(CommunityListModel.List.ViewModel(rows: response.rows))
    }
}
