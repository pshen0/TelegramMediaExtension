import UIKit

// MARK: - Cell

final class CommunityListCell: UITableViewCell {
    static let reuseId = "CommunityListCell"

    private var usesAvatarPlaceholder = false
    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()

    static func rowHeight() -> CGFloat {
        let vTop: CGFloat = 8
        let vBottom: CGFloat = 8
        let titleLine: CGFloat = 22
        let titleToSubtitle: CGFloat = 4
        let body = TMETheme.Fonts.body(15)
        let subtitleTwoLines = ceil(body.lineHeight * 2 + 1)
        return vTop + titleLine + titleToSubtitle + subtitleTwoLines + vBottom
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        accessoryType = .none
        backgroundColor = .systemGroupedBackground
        contentView.backgroundColor = .systemGroupedBackground

        avatarView.layer.cornerRadius = 26
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.isUserInteractionEnabled = false
        avatarView.accessibilityIgnoresInvertColors = true

        titleLabel.font = TMETheme.Fonts.titleSemibold(17)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = TMETheme.Fonts.body(15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = TMETheme.Fonts.body(13)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.numberOfLines = 1
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(timeLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        usesAvatarPlaceholder = false
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if usesAvatarPlaceholder {
            applyAvatarPlaceholderChrome()
        }
    }

    private func applyAvatarPlaceholderChrome() {
        avatarView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        avatarView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    func configure(community: CommunityChat, preview: String, timeText: String) {
        titleLabel.text = community.title
        subtitleLabel.text = preview
        timeLabel.text = timeText
        timeLabel.isHidden = timeText.isEmpty

        if let name = community.avatarFileName,
           let url = CommunityStore.communityAvatarURL(fileName: name),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            usesAvatarPlaceholder = false
            avatarView.contentMode = .scaleAspectFill
            avatarView.image = img.withRenderingMode(.alwaysOriginal)
            avatarView.tintColor = nil
            avatarView.backgroundColor = .clear
        } else {
            usesAvatarPlaceholder = true
            avatarView.contentMode = .center
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            avatarView.image = UIImage(systemName: "person.2.fill", withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate)
            applyAvatarPlaceholderChrome()
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let ml = contentView.layoutMargins.left
        let mr = contentView.layoutMargins.right
        let avatarSide: CGFloat = 52
        let gap: CGFloat = 12
        let titleToSubtitle: CGFloat = 4
        let titleLineH: CGFloat = 22
        let bodyFont = subtitleLabel.font ?? TMETheme.Fonts.body(15)
        let subtitleTwoLineH = ceil(bodyFont.lineHeight * 2 + 1)

        /// Вертикальное центрирование аватара: одинаковый зазор от верха/низа плашки до круга.
        let avatarY = floor((b.height - avatarSide) / 2)
        let titleY = avatarY

        timeLabel.sizeToFit()
        let timeW = timeLabel.isHidden ? 0 : min(88, max(28, ceil(timeLabel.bounds.width)))
        let timeX = b.width - mr - timeW
        timeLabel.frame = CGRect(x: timeX, y: titleY, width: timeW, height: titleLineH)

        let avatarX = ml
        avatarView.frame = CGRect(x: avatarX, y: avatarY, width: avatarSide, height: avatarSide)

        let textLeft = avatarX + avatarSide + gap
        let textRightEdge = timeLabel.isHidden ? b.width - mr : timeX - gap
        let textW = max(0, textRightEdge - textLeft)

        titleLabel.frame = CGRect(x: textLeft, y: titleY, width: textW, height: titleLineH)

        let subY = titleY + titleLineH + titleToSubtitle
        subtitleLabel.frame = CGRect(x: textLeft, y: subY, width: textW, height: subtitleTwoLineH)
    }
}
