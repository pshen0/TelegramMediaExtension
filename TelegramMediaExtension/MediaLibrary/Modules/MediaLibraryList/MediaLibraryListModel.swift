import Foundation

enum MediaLibraryListModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum ViewWillAppear {
        struct Request {}
    }

    enum UpdateSearchQuery {
        struct Request {
            let query: String
        }
    }

    enum ClearSearch {
        struct Request {}
    }

    enum ApplyTabIndex {
        struct Request {
            let index: Int
        }
    }

    enum SetKindFilter {
        struct Request {
            let kind: MediaItemKind?
        }
    }

    enum SetSort {
        struct Request {
            let sort: Sort
        }
    }

    enum ToggleAnnouncements {
        struct Request {}
    }

    enum OpenGrid {
        struct Request {}
    }

    enum AddTapped {
        struct Request {}
    }

    enum DoneTapped {
        struct Request {}
    }

    enum BannerTapped {
        struct Request {}
    }

    enum DeleteItem {
        struct Request {
            let id: UUID
        }
    }

    enum SelectItem {
        struct Request {
            let index: Int
        }
    }

    enum Sort {
        case updatedDesc
        case titleAsc
    }

    enum List {
        struct Response {
            let items: [MediaItem]
            let totalCount: Int
            let isEmpty: Bool
            let isLibraryEmpty: Bool
        }

        struct ViewModel {
            let items: [MediaItem]
            let isEmpty: Bool
            let emptyMode: MediaLibraryEmptyStateView.Mode
        }
    }
}

