import Foundation

protocol AddToMediaLibraryDisplayLogic: AnyObject {
    func displaySegmentState(_ viewModel: AddToMediaLibraryModel.SegmentState.ViewModel)
}

protocol AddToMediaLibraryPresentationLogic: AnyObject {
    func presentSegmentState(_ response: AddToMediaLibraryModel.SegmentState.Response)
}

final class AddToMediaLibraryPresenter: AddToMediaLibraryPresentationLogic {
    weak var view: AddToMediaLibraryDisplayLogic?

    func presentSegmentState(_ response: AddToMediaLibraryModel.SegmentState.Response) {
        view?.displaySegmentState(.init(selectedIndex: response.selectedIndex, showSearch: response.showSearch))
    }
}

