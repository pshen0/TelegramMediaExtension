import UIKit

protocol MediaLibraryBannerColorPickerDisplayLogic: AnyObject {
    func displayPalette(_ viewModel: MediaLibraryBannerColorPickerModel.Palette.ViewModel)
}

protocol MediaLibraryBannerColorPickerPresentationLogic: AnyObject {
    func presentPalette(_ response: MediaLibraryBannerColorPickerModel.Palette.Response)
}

final class MediaLibraryBannerColorPickerPresenter: MediaLibraryBannerColorPickerPresentationLogic {
    weak var view: MediaLibraryBannerColorPickerDisplayLogic?

    func presentPalette(_ response: MediaLibraryBannerColorPickerModel.Palette.Response) {
        view?.displayPalette(.init(colors: response.colors))
    }
}

