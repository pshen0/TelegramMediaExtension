import Foundation

// MARK: - Request / Response / ViewModel для списка сообществ (SVIP).
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
        enum RowKind {
            case member
            case discover
        }

        struct Row {
            let community: CommunityChat
            let preview: String
            let timeText: String
            let kind: RowKind
            let previewIsHiddenSpoiler: Bool
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

    enum SelectRow {
        struct Request {
            let row: List.Row
        }
    }
}
