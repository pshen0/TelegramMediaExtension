import Foundation

/// Request / Response / ViewModel для экрана списка анонсов (SVIP).
enum AnnouncementsChromeListModel {

    enum SearchScope {
        case titleOnly
        case titleDetailsLink
    }

    enum ViewDidLoad {
        struct Request {}
    }

    enum AnnouncementsChanged {
        struct Response {
            let announcements: [SavedAnnouncement]
        }

        struct ViewModel {
            let rows: [Row]
        }

        struct Row {
            let id: UUID
            let title: String
            let subtitle: String
        }
    }

    enum UpdateSearchQuery {
        struct Request {
            let query: String
        }
    }

    enum DeleteAnnouncement {
        struct Request {
            let id: UUID
        }
    }

    enum SelectAnnouncement {
        struct Request {
            let id: UUID
        }
    }
}
