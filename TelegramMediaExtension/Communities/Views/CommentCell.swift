import UIKit

final class CommentCell: UITableViewCell {
    static let reuseId = "CommentCell"

    private let bubble = UIView()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()
    private let threadChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private var showsThreadChevron = true

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubble.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { bubble.layer.cornerCurve = .continuous }
        bubble.backgroundColor = .secondarySystemGroupedBackground
        contentView.addSubview(bubble)

        bodyLabel.font = TMETheme.Fonts.body(15)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .label

        timeLabel.font = TMETheme.Fonts.body(11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right

        threadChevron.contentMode = .scaleAspectFit
        threadChevron.setContentCompressionResistancePriority(.required, for: .horizontal)
        threadChevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)

        contentView.addSubview(threadChevron)

        bubble.addSubview(bodyLabel)
        bubble.addSubview(timeLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyThreadChrome() {
        threadChevron.tintColor = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyThreadChrome()
    }

    private enum LayoutConstants {
        static let threadChevronSlot: CGFloat = 28
        static let bubbleToChevronGap: CGFloat = 6
    }

    static func height(for comment: CommunityComment, tableWidth: CGFloat, showsThreadChevron: Bool = true) -> CGFloat {
        let w = max(0, tableWidth)
        let side: CGFloat = 16
        let chevronSlot = showsThreadChevron ? LayoutConstants.threadChevronSlot + LayoutConstants.bubbleToChevronGap : 0
        let maxCardW = w - side * 2 - chevronSlot
        let padX: CGFloat = 12
        let padTop: CGFloat = 12
        let padBottom: CGFloat = 10
        let timeWMax: CGFloat = 56
        let timeH: CGFloat = 16
        let timeTrailingInset: CGFloat = 14
        let gapTextTime: CGFloat = 6
        let text = comment.text
        let textMaxWProbe = max(40, maxCardW - padX - timeTrailingInset - timeWMax - gapTextTime)
        let probeRect = (text as NSString).boundingRect(
            with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.body(15)],
            context: nil
        )
        let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
        let bubbleW = min(maxCardW, max(padX + usedTextW + gapTextTime + timeWMax + timeTrailingInset, padX * 2 + 48))
        let textMaxW = max(40, bubbleW - padX - timeTrailingInset - timeWMax - gapTextTime)
        let textRect = (text as NSString).boundingRect(
            with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.body(15)],
            context: nil
        )
        let textH = ceil(textRect.height)
        let contentBlockH = max(textH, timeH)
        let bubbleH = padTop + contentBlockH + padBottom
        return 6 + bubbleH + 6
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = contentView.bounds.width
        let side: CGFloat = 16
        let chevronSlot = showsThreadChevron ? LayoutConstants.threadChevronSlot + LayoutConstants.bubbleToChevronGap : 0
        let maxCardW = w - side * 2 - chevronSlot
        let padX: CGFloat = 12
        let padTop: CGFloat = 12
        let padBottom: CGFloat = 10
        let timeWMax: CGFloat = 56
        let timeH: CGFloat = 16
        let timeTrailingInset: CGFloat = 14
        let gapTextTime: CGFloat = 6

        let text = bodyLabel.text ?? ""
        let font = bodyLabel.font ?? UIFont.systemFont(ofSize: 15)
        let textMaxWProbe = max(40, maxCardW - padX - timeTrailingInset - timeWMax - gapTextTime)
        let probeRect = (text as NSString).boundingRect(
            with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
        let bubbleW = min(maxCardW, max(padX + usedTextW + gapTextTime + timeWMax + timeTrailingInset, padX * 2 + 48))

        let textMaxW = max(40, bubbleW - padX - timeTrailingInset - timeWMax - gapTextTime)
        let textRect = (text as NSString).boundingRect(
            with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let textH = ceil(textRect.height)
        let contentBlockH = max(textH, timeH)
        let bubbleH = padTop + contentBlockH + padBottom

        bubble.frame = CGRect(x: side, y: 6, width: bubbleW, height: bubbleH)
        bodyLabel.frame = CGRect(x: padX, y: padTop, width: textMaxW, height: textH)

        timeLabel.sizeToFit()
        let measuredTw = max(ceil(timeLabel.intrinsicContentSize.width), ceil(timeLabel.bounds.width))
        var tw = min(timeWMax, measuredTw + 4)
        let maxTw = bubbleW - padX - timeTrailingInset
        tw = min(tw, max(20, maxTw))
        let timeX = max(padX, bubbleW - timeTrailingInset - tw)
        timeLabel.frame = CGRect(x: timeX, y: padTop + contentBlockH - timeH, width: tw, height: timeH)

        if showsThreadChevron {
            threadChevron.isHidden = false
            let slot = LayoutConstants.threadChevronSlot
            let cgap = LayoutConstants.bubbleToChevronGap
            let chevronX = min(w - side - slot, bubble.frame.maxX + cgap)
            threadChevron.frame = CGRect(x: chevronX, y: (contentView.bounds.height - 18) / 2, width: slot, height: 18)
        } else {
            threadChevron.isHidden = true
            threadChevron.frame = .zero
        }
    }

    func configure(comment: CommunityComment, showsThreadChevron: Bool = true) {
        self.showsThreadChevron = showsThreadChevron
        bodyLabel.text = comment.text
        timeLabel.text = Self.shortTime(comment.createdAt)
        threadChevron.isHidden = !showsThreadChevron
        setNeedsLayout()
    }

    private static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

