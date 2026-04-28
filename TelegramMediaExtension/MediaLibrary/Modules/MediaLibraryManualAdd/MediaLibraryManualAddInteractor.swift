import Foundation

protocol MediaLibraryManualAddBusinessLogic: AnyObject {
    func viewDidLoad(_ request: MediaLibraryManualAddModel.ViewDidLoad.Request)
    func openForm(_ request: MediaLibraryManualAddModel.OpenForm.Request)
}

protocol MediaLibraryManualAddRoutingLogic: AnyObject {
    func routeToCreateForm()
}

final class MediaLibraryManualAddInteractor: MediaLibraryManualAddBusinessLogic {
    weak var router: MediaLibraryManualAddRoutingLogic?

    func viewDidLoad(_ request: MediaLibraryManualAddModel.ViewDidLoad.Request) {}

    func openForm(_ request: MediaLibraryManualAddModel.OpenForm.Request) {
        router?.routeToCreateForm()
    }
}

