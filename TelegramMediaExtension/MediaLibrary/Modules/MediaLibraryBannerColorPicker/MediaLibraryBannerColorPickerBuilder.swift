import UIKit

enum MediaLibraryBannerColorPickerBuilder {
    static func build() -> MediaLibraryBannerColorPickerViewController {
        let presenter = MediaLibraryBannerColorPickerPresenter()
        let interactor = MediaLibraryBannerColorPickerInteractor(presenter: presenter)
        let view = MediaLibraryBannerColorPickerViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}

