import Foundation

/// Request / Response / ViewModel для экрана чата сообщества (SVIP).
enum CommunityChatModel {

    enum ViewDidLoad {
        struct Request {}
    }

    enum Messages {
        struct Response {
            let messages: [CommunityMessage]
            let scrollAnimated: Bool
        }

        struct ViewModel {
            let messages: [CommunityMessage]
            let scrollAnimated: Bool
        }
    }

    enum NavigationTitle {
        struct Response {
            let title: String
        }
    }

    enum InputAvailability {
        struct Response {
            let canSendMessages: Bool
        }

        struct ViewModel {
            let canSendMessages: Bool
        }
    }

    enum SendMessage {
        struct Request {
            let text: String
            let spoilerTags: [CommunitySpoilerTag]
        }
    }

    /// Решение об оверлее спойлера для ячейки (логика прогресса медиатеки).
    struct SpoilerDecision: Equatable {
        let title: String
        let subtitle: String
        let messageId: UUID
    }
}
