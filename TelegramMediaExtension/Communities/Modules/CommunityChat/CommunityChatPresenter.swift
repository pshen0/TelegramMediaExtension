import Foundation

protocol CommunityChatDisplayLogic: AnyObject {
    func displayMessages(_ viewModel: CommunityChatModel.Messages.ViewModel)
    func displayNavigationTitle(_ title: String)
    func reloadCellsForDependentStores()
}

protocol CommunityChatPresentationLogic: AnyObject {
    func presentMessages(_ response: CommunityChatModel.Messages.Response)
    func presentCommunityTitle(_ response: CommunityChatModel.NavigationTitle.Response)
    func notifyDependentStoresChanged()
}

final class CommunityChatPresenter: CommunityChatPresentationLogic {

    weak var view: CommunityChatDisplayLogic?

    func presentMessages(_ response: CommunityChatModel.Messages.Response) {
        view?.displayMessages(
            CommunityChatModel.Messages.ViewModel(messages: response.messages, scrollAnimated: response.scrollAnimated)
        )
    }

    func presentCommunityTitle(_ response: CommunityChatModel.NavigationTitle.Response) {
        view?.displayNavigationTitle(response.title)
    }

    func notifyDependentStoresChanged() {
        view?.reloadCellsForDependentStores()
    }
}
