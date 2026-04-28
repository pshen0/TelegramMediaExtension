import UIKit

protocol MediaLibraryBannerColorPickerBusinessLogic: AnyObject {
    func viewDidLoad(_ request: MediaLibraryBannerColorPickerModel.ViewDidLoad.Request)
    func selectColor(_ request: MediaLibraryBannerColorPickerModel.SelectColor.Request)
}

protocol MediaLibraryBannerColorPickerRoutingLogic: AnyObject {
    func routeFinishAndDismiss()
}

final class MediaLibraryBannerColorPickerInteractor: MediaLibraryBannerColorPickerBusinessLogic {
    private let presenter: MediaLibraryBannerColorPickerPresentationLogic
    weak var router: MediaLibraryBannerColorPickerRoutingLogic?

    init(presenter: MediaLibraryBannerColorPickerPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: MediaLibraryBannerColorPickerModel.ViewDidLoad.Request) {
        presenter.presentPalette(.init(colors: MediaLibraryBannerColorPickerViewController.palette))
    }

    func selectColor(_ request: MediaLibraryBannerColorPickerModel.SelectColor.Request) {
        let colors = MediaLibraryBannerColorPickerViewController.palette
        guard request.index >= 0, request.index < colors.count else { return }
        MediaLibraryHeaderBannerColor.setCustom(colors[request.index])
        router?.routeFinishAndDismiss()
    }
}

