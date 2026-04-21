import UIKit

enum TMETheme {
    enum Colors {
        // Telegram-like defaults (approx), kept lightweight and UIKit-only.
        static let accent = UIColor(red: 0.19, green: 0.64, blue: 0.98, alpha: 1.0)
        static let background = UIColor.systemBackground
        static let groupedBackground = UIColor.systemGroupedBackground
        static let secondaryGroupedBackground = UIColor.secondarySystemGroupedBackground
        static let separator = UIColor.separator
        static let secondaryText = UIColor.secondaryLabel
        /// Поле поиска «как в контактах» (светло-серый фон).
        static let searchFieldBackground = UIColor.secondarySystemFill
        /// Лёгкий разделитель строк списка.
        static let listSeparator = UIColor.separator.withAlphaComponent(0.55)
    }
    
    enum Fonts {
        static func titleSemibold(_ size: CGFloat) -> UIFont { .systemFont(ofSize: size, weight: .semibold) }
        static func body(_ size: CGFloat) -> UIFont { .systemFont(ofSize: size, weight: .regular) }
    }
}

