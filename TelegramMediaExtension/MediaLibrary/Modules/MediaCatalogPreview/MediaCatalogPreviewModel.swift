import Foundation

enum MediaCatalogPreviewModel {
    enum Build {
        struct Request {
            let candidate: MediaCatalogCandidate
        }
    }

    enum LoadDetailIfNeeded {
        struct Request {}
    }

    enum AddTapped {
        struct Request {}
    }

    enum Content {
        struct Response {
            let title: String
            let kindTitle: String
            let metaText: String
            let synopsisText: String
            let hintText: String?
        }

        struct ViewModel {
            let title: String
            let kindTitle: String
            let metaText: String
            let synopsisText: String
            let hintText: String?
        }
    }
}

