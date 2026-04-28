import Foundation

enum MediaCatalogSearchModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum QueryChanged {
        struct Request {
            let query: String
        }
    }

    enum List {
        struct Row {
            let candidate: MediaCatalogCandidate
            let secondaryText: String
        }

        struct Response {
            let rows: [Row]
        }

        struct ViewModel {
            let rows: [Row]
        }
    }
}

