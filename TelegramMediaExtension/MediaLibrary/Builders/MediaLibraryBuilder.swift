import UIKit

/// Точка входа в модуль (аналог фабрики экрана в Telegram).
enum MediaLibraryBuilder {
    static func build() -> UIViewController {
        MediaLibraryListBuilder.build()
    }
}
