import UIKit

enum MediaLibraryBannerColorPickerModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum SelectColor {
        struct Request {
            let index: Int
        }
    }

    enum Palette {
        struct Response {
            let colors: [UIColor]
        }

        struct ViewModel {
            let colors: [UIColor]
        }
    }
}

