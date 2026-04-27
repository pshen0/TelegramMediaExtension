import Foundation

/// Request / Response / ViewModel для списка сообществ (SVIP).
enum CommunityListModel {

    enum ViewDidLoad {
        struct Request {}
    }

    enum UpdateSearch {
        struct Request {
            let query: String
        }
    }

    enum List {
        struct Row {
            let community: CommunityChat
            let preview: String
            let timeText: String
        }

        struct Response {
            let rows: [Row]
        }

        struct ViewModel {
            let rows: [Row]
        }
    }

    enum DeleteCommunity {
        struct Request {
            let id: UUID
        }
    }

    enum CreateCommunity {
        struct Request {
            let title: String
        }
    }
}
