import UIKit

/// Сплошной фон списка (градиент только в шапке таблицы, чтобы уезжал при скролле).
final class MediaLibraryTableBackgroundView: UIView {
    private let solidFill = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        solidFill.backgroundColor = .systemBackground
        addSubview(solidFill)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        solidFill.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        solidFill.backgroundColor = .systemBackground
    }
}
