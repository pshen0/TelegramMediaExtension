import UIKit

/// Пустая медиатека: текст по центру полосы между нижним краем шапки (вкладки) и низом экрана.
final class MediaLibraryEmptyStateView: UIView {
    private let label = UILabel()

    /// Нижняя граница блока вкладок в координатах этого view (обновляется при скролле шапки).
    var headerBottomY: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    /// Отступ снизу до индикатора Home и т.п.
    var bottomSafeInset: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

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
    }

    var mode: Mode = .libraryEmpty {
        didSet { applyMode() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel

        addSubview(label)
        applyMode()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyMode() {
        label.text = mode.title + "\n\n" + mode.message
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width - 64
        let bandTop = min(headerBottomY, bounds.height - 80)
        let bandBottom = bounds.height - bottomSafeInset
        let bandH = max(60, bandBottom - bandTop)
        let labelSize = label.sizeThatFits(CGSize(width: max(100, w), height: CGFloat.greatestFiniteMagnitude))
        let y = bandTop + (bandH - labelSize.height) / 2
        label.frame = CGRect(x: 32, y: max(bandTop + 8, y), width: max(100, w), height: labelSize.height)
    }
}
