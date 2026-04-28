import Foundation

protocol CommunityChatDisplayLogic: AnyObject {
    func displayMessages(_ viewModel: CommunityChatModel.Messages.ViewModel)
    func displayNavigationTitle(_ title: String)
    func displayInputAvailability(_ viewModel: CommunityChatModel.InputAvailability.ViewModel)
    func reloadCellsForDependentStores()
}

protocol CommunityChatPresentationLogic: AnyObject {
    func presentMessages(_ response: CommunityChatModel.Messages.Response)
    func presentCommunityTitle(_ response: CommunityChatModel.NavigationTitle.Response)
    func presentInputAvailability(_ response: CommunityChatModel.InputAvailability.Response)
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

    func presentInputAvailability(_ response: CommunityChatModel.InputAvailability.Response) {
        view?.displayInputAvailability(
            CommunityChatModel.InputAvailability.ViewModel(canSendMessages: response.canSendMessages)
        )
    }

    func notifyDependentStoresChanged() {
        view?.reloadCellsForDependentStores()
    }
}
