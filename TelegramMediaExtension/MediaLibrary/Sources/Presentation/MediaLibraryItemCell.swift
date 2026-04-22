import UIKit

/// Ячейка каталога: постер, название, статус, чипы хэштегов (ТЗ 4.1.5).
final class MediaLibraryItemCell: UITableViewCell {
    static let reuseIdentifier = "MediaLibraryItemCell"

    private let posterView = UIImageView()
    private var usesPosterPlaceholder = false
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        posterView.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            posterView.layer.cornerCurve = .continuous
        }
        posterView.backgroundColor = UIColor.secondarySystemFill

        titleLabel.font = TMETheme.Fonts.titleSemibold(16)
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        statusLabel.font = TMETheme.Fonts.body(13)
        statusLabel.textColor = TMETheme.Colors.secondaryText
        statusLabel.numberOfLines = 1
        statusLabel.lineBreakMode = .byTruncatingTail

        chipScroll.showsHorizontalScrollIndicator = false
        chipStack.axis = .horizontal
        chipStack.spacing = 6
        chipStack.alignment = .center

        contentView.addSubview(posterView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(chipScroll)
        chipScroll.addSubview(chipStack)

        accessoryType = .disclosureIndicator
        selectionStyle = .default
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MediaItem) {
        titleLabel.text = item.title

        var statusLine = item.status.title
        statusLine += " · " + item.kind.title
        if let p = item.progress.displayString(kind: item.kind) {
            statusLine += " · " + p
        }
        statusLabel.text = statusLine

        if let url = MediaLibraryStore.coverImageURL(fileName: item.coverFileName),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            usesPosterPlaceholder = false
            posterView.contentMode = .scaleAspectFill
            posterView.image = img
            posterView.backgroundColor = .clear
            posterView.tintColor = nil
        } else {
            usesPosterPlaceholder = true
            posterView.contentMode = .center
            let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
            posterView.image = UIImage(systemName: symbolForKind(item.kind), withConfiguration: config)
            applyPosterPlaceholderColors()
        }

        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in item.hashtags.prefix(12) {
            chipStack.addArrangedSubview(ChipPill(text: "#" + tag))
        }
        chipScroll.isHidden = item.hashtags.isEmpty
    }

    func refreshPlaceholderIfNeeded() {
        guard usesPosterPlaceholder else { return }
        applyPosterPlaceholderColors()
    }

    private func applyPosterPlaceholderColors() {
        posterView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        posterView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if usesPosterPlaceholder {
            applyPosterPlaceholderColors()
        }
    }

    private func symbolForKind(_ kind: MediaItemKind) -> String {
        switch kind {
        case .film: return "film"
        case .series: return "tv"
        case .book: return "book.closed"
        case .musicAlbum: return "music.note.list"
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let margin: CGFloat = 16
        let posterSide: CGFloat = 72
        let topPad: CGFloat = 12
        posterView.frame = CGRect(x: margin, y: topPad, width: posterSide, height: posterSide)

        let textX = posterView.frame.maxX + 12
        let textW = max(0, contentView.bounds.width - textX - margin - 28)
        titleLabel.frame = CGRect(x: textX, y: topPad, width: textW, height: 40)
        statusLabel.frame = CGRect(x: textX, y: titleLabel.frame.maxY + 2, width: textW, height: 18)

        let chipH: CGFloat = chipScroll.isHidden ? 0 : 28
        let chipY = statusLabel.frame.maxY + (chipScroll.isHidden ? 0 : 6)
        chipScroll.frame = CGRect(x: textX, y: chipY, width: textW, height: chipH)
        let fit = chipStack.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingExpandedSize.width, height: chipH),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        chipStack.frame = CGRect(x: 0, y: 0, width: max(textW, fit.width), height: chipH)
        chipScroll.contentSize = CGSize(width: chipStack.frame.width, height: chipH)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        usesPosterPlaceholder = false
        posterView.image = nil
        posterView.contentMode = .scaleAspectFill
        posterView.tintColor = nil
        posterView.backgroundColor = UIColor.secondarySystemFill
    }
}

private final class ChipPill: UIView {
    private let label = UILabel()

    init(text: String) {
        super.init(frame: .zero)
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = TMETheme.Colors.accent
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        backgroundColor = TMETheme.Colors.accent.withAlphaComponent(0.12)
        layer.cornerRadius = 12
        clipsToBounds = true
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 8, dy: 4)
    }

    override var intrinsicContentSize: CGSize {
        let s = label.sizeThatFits(CGSize(width: 240, height: 40))
        return CGSize(width: s.width + 16, height: max(26, s.height + 8))
    }
}
