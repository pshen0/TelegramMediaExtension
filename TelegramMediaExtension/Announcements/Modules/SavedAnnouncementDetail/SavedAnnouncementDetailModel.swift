import Foundation

/// Request / Response / ViewModel для карточки сохранённого анонса (SVIP).
enum SavedAnnouncementDetailModel {

    enum ViewDidLoad {
        struct Request {}
    }

    enum ViewWillAppear {
        struct Request {}
    }

    enum RefreshDisplay {
        struct Request {
            /// Совпадает с логикой баннера: есть JPEG и ненулевая высота.
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
            /// Градиент и заголовок на баннере (при отсутствии картинки — только текстовый заголовок в контенте).
            let showHeroChrome: Bool
            let rows: [ContentRow]
        }
    }
}
