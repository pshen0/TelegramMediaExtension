import UIKit

enum MediaLibraryBuilder {
    static func build() -> UIViewController {
        MediaLibraryListBuilder.build()
    }
}
