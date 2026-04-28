import UIKit

enum MediaLibraryManualAddBuilder {
    static func build() -> MediaLibraryManualAddViewController {
        let interactor = MediaLibraryManualAddInteractor()
        let view = MediaLibraryManualAddViewController(interactor: interactor)
        interactor.router = view
        return view
    }
}

