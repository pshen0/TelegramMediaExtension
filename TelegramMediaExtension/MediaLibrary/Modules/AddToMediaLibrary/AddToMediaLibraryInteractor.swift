import Foundation

protocol AddToMediaLibraryBusinessLogic: AnyObject {
    func viewDidLoad(_ request: AddToMediaLibraryModel.ViewDidLoad.Request)
    func segmentChanged(_ request: AddToMediaLibraryModel.SegmentChanged.Request)
}

final class AddToMediaLibraryInteractor: AddToMediaLibraryBusinessLogic {
    private let presenter: AddToMediaLibraryPresentationLogic
    private var selectedIndex: Int = 0

    init(presenter: AddToMediaLibraryPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: AddToMediaLibraryModel.ViewDidLoad.Request) {
        pushState()
    }

    func segmentChanged(_ request: AddToMediaLibraryModel.SegmentChanged.Request) {
        selectedIndex = request.selectedIndex
        pushState()
    }

    private func pushState() {
        presenter.presentSegmentState(
            .init(
                selectedIndex: selectedIndex,
                showSearch: selectedIndex == 0
            )
        )
    }
}

