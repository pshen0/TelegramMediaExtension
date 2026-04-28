import Foundation

enum TMESettingsModel {
    enum ViewDidLoad {
        struct Request {}
    }

    enum Rows {
        enum Action {
            case openMediaLibrary
            case openAnnouncements
            case openBackendURL
        }

        struct Row {
            let iconName: String
            let title: String
            let detail: String?
            let showsChevron: Bool
            let iconScale: CGFloat?
            let action: Action?
        }

        struct Group {
            let rows: [Row]
        }

        struct Response {
            let groups: [Group]
        }

        struct ViewModel {
            let groups: [Group]
        }
    }
}

