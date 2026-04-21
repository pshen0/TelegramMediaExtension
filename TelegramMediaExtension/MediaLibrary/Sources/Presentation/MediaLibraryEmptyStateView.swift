import UIKit

/// Пустая медиатека (ТЗ 4.1.5): иллюстрация + текст.
final class MediaLibraryEmptyStateView: UIView {
    private let imageView = UIImageView()
    private let label = UILabel()

    enum Mode {
        case libraryEmpty
        case filteredEmpty

        var title: String {
            switch self {
            case .libraryEmpty:
                return "Ваша медиатека пуста"
            case .filteredEmpty:
                return "Ничего не найдено"
            }
        }

        var message: String {
            switch self {
            case .libraryEmpty:
                return "Добавьте первый фильм, сериал или книгу через кнопку «+»."
            case .filteredEmpty:
                return "Попробуйте изменить поиск или фильтры."
            }
        }

        var symbolName: String {
            switch self {
            case .libraryEmpty: return "rectangle.stack.badge.plus"
            case .filteredEmpty: return "line.3.horizontal.decrease.circle"
            }
        }
    }

    var mode: Mode = .libraryEmpty {
        didSet { applyMode() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.secondaryLabel.withAlphaComponent(0.55)
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .light)

        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel

        addSubview(imageView)
        addSubview(label)
        applyMode()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyMode() {
        imageView.image = UIImage(systemName: mode.symbolName)
        label.text = mode.title + "\n\n" + mode.message
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        let top = max(0, h * 0.18)
        imageView.frame = CGRect(x: (w - 100) / 2, y: top, width: 100, height: 100)
        let labelY = imageView.frame.maxY + 20
        label.frame = CGRect(x: 32, y: labelY, width: w - 64, height: h - labelY - 24)
    }
}
