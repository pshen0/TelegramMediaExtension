import Foundation

enum MediaItemEditorModel {
    enum Build {
        struct Request {
            let mode: MediaItemEditorViewController.Mode
        }
    }

    enum ViewDidLoad {
        struct Request {}
    }

    enum SaveTapped {
        struct Request {}
    }

    enum DeleteConfirmed {
        struct Request {}
    }

    enum UpdateKind {
        struct Request {
            let kind: MediaItemKind
        }
    }

    enum UpdateStatus {
        struct Request {
            let status: MediaWatchStatus
        }
    }

    enum UpdateField {
        struct Request {
            let field: Field
        }

        enum Field {
            case title(String)
            case year(Int?)
            case genre(String?)
            case rating(Double?)
            case synopsis(String?)
            case progressSeason(Int?)
            case progressCurrent(Int?)
            case progressTotal(Int?)
            case spoilersProtectionEnabled(Bool)
            case notes(String)
            case hashtags([String])
            case coverFileName(String?)
        }
    }

    enum Content {
        struct Response {
            let mode: MediaItemEditorViewController.Mode
            let item: MediaItem
            let navigationTitle: String
            let canDelete: Bool
        }

        struct ViewModel {
            let mode: MediaItemEditorViewController.Mode
            let item: MediaItem
            let navigationTitle: String
            let canDelete: Bool
        }
    }

    enum ErrorAlert {
        struct ViewModel {
            let title: String
            let message: String?
        }
    }
}

