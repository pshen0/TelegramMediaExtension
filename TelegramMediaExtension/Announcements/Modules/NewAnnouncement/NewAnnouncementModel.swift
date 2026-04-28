import Foundation

//MARK: - Request / Response / ViewModel для экрана нового/редактируемого анонса (SVIP).
enum NewAnnouncementModel {

    enum Mode {
        case community(UUID)
        case personal
        case editSaved(UUID)
    }

    enum ViewDidLoad {
        struct Request {}
    }

    enum Chrome {
        struct ViewModel {
            let navTitle: String
            let doneAccessibilityLabel: String
        }
    }

    enum Validation {
        struct ViewModel {
            let title: String
            let message: String?
        }
    }

    enum UpdateTitle {
        struct Request { let title: String }
    }

    enum UpdateDetails {
        struct Request { let details: String }
    }

    enum UpdateLink {
        struct Request { let link: String }
    }

    enum SetDate {
        struct Request { let date: Date }
    }

    enum SetLocation {
        struct Request { let location: CommunityLocation }
    }

    enum SavePickedImage {
        struct Request { let jpegData: Data }
    }

    enum Submit {
        struct Request {}
    }
}
