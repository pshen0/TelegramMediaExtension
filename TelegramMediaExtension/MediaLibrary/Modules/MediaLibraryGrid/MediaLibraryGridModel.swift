import Foundation

enum MediaLibraryGridModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum ViewWillAppear {
        struct Request {}
    }

    enum SelectItem {
        struct Request {
            let index: Int
        }
    }

    enum List {
        struct Response {
            let items: [MediaItem]
        }

        struct ViewModel {
            let items: [MediaItem]
        }
    }
}

