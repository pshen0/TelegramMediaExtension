import Foundation

// MARK: - Request / Response / ViewModel для экрана комментариев (SVIP).
enum CommunityCommentsModel {

    enum ViewDidLoad {
        struct Request {}
    }

    enum CommentsList {
        struct Response {
            let comments: [CommunityComment]
            let scrollAnimated: Bool
        }

        struct ViewModel {
            let comments: [CommunityComment]
            let scrollAnimated: Bool
        }
    }

    enum SendComment {
        struct Request {
            let text: String
        }
    }
}
