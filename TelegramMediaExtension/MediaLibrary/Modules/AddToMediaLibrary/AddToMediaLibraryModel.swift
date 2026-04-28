import Foundation

enum AddToMediaLibraryModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum SegmentChanged {
        struct Request {
            let selectedIndex: Int
        }
    }

    enum SegmentState {
        struct Response {
            let selectedIndex: Int
            let showSearch: Bool
        }

        struct ViewModel {
            let selectedIndex: Int
            let showSearch: Bool
        }
    }
}

