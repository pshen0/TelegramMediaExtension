import Foundation

enum MediaItemDetailModel {
    enum Build {
        struct Request {
            let item: MediaItem
        }
    }

    enum ViewDidLoad {
        struct Request {}
    }

    enum ViewWillAppear {
        struct Request {}
    }

    enum UpdateStatus {
        struct Request {
            let index: Int
        }
    }

    enum ToggleFavorite {
        struct Request {}
    }

    enum Share {
        struct Request {}
    }

    enum ExportJSON {
        struct Request {}
    }

    enum Delete {
        struct Request {}
    }

    enum Edit {
        struct Request {}
    }

    enum Content {
        struct Response {
            let item: MediaItem
            let title: String
            let metaText: String
            let synopsisText: String
            let synopsisIsPlaceholder: Bool
            let statusIndex: Int
            let progressText: String
            let notesText: String
            let tagsText: String
            let tagsArePlaceholder: Bool
        }

        struct ViewModel {
            let title: String
            let metaText: String
            let synopsisText: String
            let synopsisIsPlaceholder: Bool
            let statusIndex: Int
            let progressText: String
            let notesText: String
            let tagsText: String
            let tagsArePlaceholder: Bool
            let isFavorite: Bool
            let kind: MediaItemKind
            let coverFileName: String?
        }
    }
}

