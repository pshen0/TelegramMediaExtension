import Foundation

//MARK: - Request / Response / ViewModel для карточки сохранённого анонса (SVIP).
enum SavedAnnouncementDetailModel {

    enum ViewDidLoad {
        struct Request {}
    }

    enum ViewWillAppear {
        struct Request {}
    }

    enum RefreshDisplay {
        struct Request {
            let heroStripVisible: Bool
        }
    }

    enum EditTap {
        struct Request {}
    }

    enum OpenLink {
        struct Request {
            let trimmed: String
        }
    }

    enum LoadAnnouncement {
        struct Response {
            let announcement: SavedAnnouncement
            let heroStripVisible: Bool
            let communitySourceName: String?
        }

        enum ContentRow: Equatable {
            case inlineTitle(String)
            case field(title: String, body: String, secondary: Bool)
            case linkButton(trimmed: String)
        }

        struct ViewModel {
            let heroTitle: String
            let showHeroChrome: Bool
            let rows: [ContentRow]
        }
    }
}
