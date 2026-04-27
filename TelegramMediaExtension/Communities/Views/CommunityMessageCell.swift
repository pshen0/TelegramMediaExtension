import UIKit

final class CommunityMessageCell: UITableViewCell {
    static let reuseId = "CommunityMessageCell"

    /// Вертикальные отступы между карточками в ленте (одинаково для поста и анонса).
    private enum LayoutMetrics {
        static let spacingAboveCard: CGFloat = 5
        static let spacingBelowCard: CGFloat = 5
        static let horizontalInset: CGFloat = 8
        static let announcementInnerTop: CGFloat = 5
        static let announcementImageHeight: CGFloat = 180
        /// Выравниваем с полями текста анонса.
        static let announcementImageSideInset: CGFloat = 9
        static let announcementImageBottomGap: CGFloat = 5
        static let titleBodyGap: CGFloat = 4
        static let bodyBottomGap: CGFloat = 5
        /// Совпадает с `bodyBottomGap`, чтобы высота строки и вёрстка совпадали со ссылкой и без.
        static let linkBottomGap: CGFloat = 5
        static let footerRowHeight: CGFloat = 22
        static let footerBottomPadding: CGFloat = 5
        /// Поля текста анонса от края пузыря.
        static let announcementTextSideInset: CGFloat = 9
        /// Текст поста от краёв пузыря (время считается от того же базового края).
        static let postTextSideInset: CGFloat = 9
        static let announcementTimeTrailingInset: CGFloat = 7
        static let footerLocationTimeGap: CGFloat = 4
    }

    var onSaveAnnouncement: ((CommunityMessage) -> Void)?
    var onOpenComments: ((CommunityMessage) -> Void)?
    var onOpenLink: ((URL) -> Void)?
    var onOpenLocation: ((CommunityLocation) -> Void)?
    var onRevealSpoiler: ((UUID) -> Void)?
    private var message: CommunityMessage?
    private var announcementIsSaved = false
    private var spoilerDecision: CommunityChatModel.SpoilerDecision?
    private var spoilerIsRevealed = false

    /// Анонс: полноширинная карточка
    private let bubble = UIView()
    private let announcementImageView = UIImageView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let linkButton = UIButton(type: .system)
    private let locationButton = UIButton(type: .system)
    private let timeLabel = UILabel()

    /// Пост: один пузырь — текст + время внизу справа, снизу строка «Leave a Comment»
    private let postBubble = UIView()
    private let postDivider = UIView()
    private let actionsRow = UIControl()
    private let actionsIcon = UIImageView()
    private let actionsLabel = UILabel()
    private let actionsChevron = UIImageView()

    private let spoilerOverlay = SpoilerOverlayView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        for v in [bubble, postBubble] {
            v.layer.cornerRadius = 16
            if #available(iOS 13.0, *) { v.layer.cornerCurve = .continuous }
        }
        /// Как у комментариев: на `systemGroupedBackground` не сливаться со страницей.
        bubble.backgroundColor = .secondarySystemGroupedBackground
        postBubble.backgroundColor = .secondarySystemGroupedBackground

        postDivider.backgroundColor = UIColor.separator.withAlphaComponent(0.55)

        announcementImageView.contentMode = .scaleAspectFill
        announcementImageView.clipsToBounds = true
        announcementImageView.layer.cornerRadius = 12
        if #available(iOS 13.0, *) {
            announcementImageView.layer.cornerCurve = .continuous
        }

        titleLabel.font = TMETheme.Fonts.titleSemibold(15)
        titleLabel.numberOfLines = 0

        bodyLabel.font = TMETheme.Fonts.body(15)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .label

        actionsRow.isAccessibilityElement = true
        actionsRow.accessibilityTraits = [.button]
        actionsRow.addTarget(self, action: #selector(actionsTapped), for: .touchUpInside)

        actionsIcon.image = UIImage(systemName: "bubble.left")
        actionsIcon.contentMode = .scaleAspectFit

        actionsLabel.font = TMETheme.Fonts.body(14)
        actionsLabel.text = "Leave a Comment"

        actionsChevron.image = UIImage(systemName: "chevron.right")
        actionsChevron.contentMode = .scaleAspectFit

        linkButton.titleLabel?.font = TMETheme.Fonts.body(13)
        linkButton.contentHorizontalAlignment = .left
        linkButton.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)

        locationButton.titleLabel?.font = TMETheme.Fonts.body(14)
        locationButton.titleLabel?.lineBreakMode = .byTruncatingTail
        locationButton.contentHorizontalAlignment = .left
        locationButton.addTarget(self, action: #selector(locationTapped), for: .touchUpInside)

        applyMediaLibraryChromeColors()

        timeLabel.font = TMETheme.Fonts.body(11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right

        contentView.addSubview(bubble)
        contentView.addSubview(postBubble)
        contentView.addSubview(spoilerOverlay)

        bubble.addSubview(announcementImageView)
        bubble.addSubview(titleLabel)
        bubble.addSubview(bodyLabel)
        bubble.addSubview(linkButton)
        bubble.addSubview(locationButton)
        bubble.addSubview(timeLabel)

        postBubble.addSubview(postDivider)
        postBubble.addSubview(actionsRow)
        actionsRow.addSubview(actionsIcon)
        actionsRow.addSubview(actionsLabel)
        actionsRow.addSubview(actionsChevron)

        if #available(iOS 13.0, *) {
            bubble.addInteraction(UIContextMenuInteraction(delegate: self))
        }

        postBubble.isHidden = true
        spoilerOverlay.isHidden = true
        spoilerOverlay.onTap = { [weak self] in
            guard let self, let msg = self.message else { return }
            self.onRevealSpoiler?(msg.id)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        message = nil
        announcementIsSaved = false
        spoilerDecision = nil
        spoilerIsRevealed = false
        spoilerOverlay.isHidden = true
        spoilerOverlay.title = ""
        spoilerOverlay.subtitle = ""
        onRevealSpoiler = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeColors()
    }

    /// Цвета «Leave a Comment», ссылок и места — как шапка медиатеки (обновлять при смене цвета в каталоге).
    func applyMediaLibraryChromeColors() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        actionsIcon.tintColor = c
        actionsLabel.textColor = c
        actionsChevron.tintColor = c
        linkButton.setTitleColor(c, for: .normal)
        linkButton.tintColor = c
        locationButton.setTitleColor(c, for: .normal)
        locationButton.tintColor = c
    }

    /// Та же высота, что даёт `linkButton.sizeThatFits` в layout — иначе строка таблицы не совпадает с карточкой при ссылке.
    private static func announcementLinkButtonBlockHeight(displayTitle: String, innerWidth: CGFloat) -> CGFloat {
        let b = UIButton(type: .system)
        b.titleLabel?.font = TMETheme.Fonts.body(13)
        b.titleLabel?.numberOfLines = 2
        b.setTitle(displayTitle, for: .normal)
        return ceil(b.sizeThatFits(CGSize(width: innerWidth, height: 500)).height)
    }

    static func height(for message: CommunityMessage, tableWidth: CGFloat) -> CGFloat {
        let w = max(0, tableWidth)
        let side = LayoutMetrics.horizontalInset
        let maxCardW = w - side * 2
        if message.kind == .post {
            let text = message.text
            let padX = LayoutMetrics.postTextSideInset
            let padTop: CGFloat = 5
            let padBottom: CGFloat = 5
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let timeTrailingInset: CGFloat = 7
            let gapTextTime: CGFloat = 3
            let sepGapTop: CGFloat = 4
            let sepH: CGFloat = 1
            let sepGapBottom: CGFloat = 2
            let stripH: CGFloat = 40
            let stripHPadding: CGFloat = 6
            let icon: CGFloat = 22
            let chev: CGFloat = 14
            let gap: CGFloat = 8
            let lw = ceil(("Leave a Comment" as NSString).size(withAttributes: [.font: TMETheme.Fonts.body(14)]).width)
            let stripIntrinsic = stripHPadding * 2 + icon + gap + lw + gap + chev

            let textMaxWProbe = max(40, maxCardW - padX - timeTrailingInset - timeWMax - gapTextTime)
            let probeRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(15)],
                context: nil
            )
            let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
            let bubbleW = min(maxCardW, max(stripIntrinsic, padX + usedTextW + gapTextTime + timeWMax + timeTrailingInset))
            let textMaxW = max(40, bubbleW - padX - timeTrailingInset - timeWMax - gapTextTime)
            let textRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(15)],
                context: nil
            )
            let textH = ceil(textRect.height)
            let contentBlockH = max(textH, timeH)
            let bubbleH = padTop + contentBlockH + sepGapTop + sepH + sepGapBottom + stripH + padBottom

            return LayoutMetrics.spacingAboveCard + bubbleH + LayoutMetrics.spacingBelowCard
        }

        let bw = maxCardW
        let textInset = LayoutMetrics.announcementTextSideInset
        let textContentW = bw - textInset * 2

        let a = message.announcement
        let imgExists: Bool = {
            guard let name = a?.imageFileName, let u = CommunityStore.announcementImageURL(fileName: name) else { return false }
            return FileManager.default.fileExists(atPath: u.path)
        }()
        var y: CGFloat
        if imgExists {
            y = LayoutMetrics.announcementImageSideInset + LayoutMetrics.announcementImageHeight + LayoutMetrics.announcementImageBottomGap
        } else {
            y = LayoutMetrics.announcementInnerTop
        }

        let title = "Анонс" + (a?.title.isEmpty == false ? ": \(a!.title)" : "")
        let titleH = ceil((title as NSString).boundingRect(
            with: CGSize(width: textContentW, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.titleSemibold(15)],
            context: nil
        ).height)
        y += titleH + LayoutMetrics.titleBodyGap

        let bodyText = (a?.details?.isEmpty == false ? a!.details : message.text) ?? ""
        let bh = ceil((bodyText as NSString).boundingRect(
            with: CGSize(width: textContentW, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.body(15)],
            context: nil
        ).height)
        y += max(1, bh) + LayoutMetrics.bodyBottomGap

        if let link = a?.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
            let t = "Ссылка: \(link)"
            y += announcementLinkButtonBlockHeight(displayTitle: t, innerWidth: textContentW) + LayoutMetrics.linkBottomGap
        }
        y += LayoutMetrics.footerRowHeight + LayoutMetrics.footerBottomPadding
        return LayoutMetrics.spacingAboveCard + y + LayoutMetrics.spacingBelowCard
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let message else { return }
        let w = contentView.bounds.width
        let side = LayoutMetrics.horizontalInset
        let maxCardW = w - side * 2

        if message.kind == .post {
            bubble.isHidden = true
            postBubble.isHidden = false

            let padX = LayoutMetrics.postTextSideInset
            let padTop: CGFloat = 5
            let padBottom: CGFloat = 5
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let timeTrailingInset: CGFloat = 7
            let gapTextTime: CGFloat = 3
            let sepGapTop: CGFloat = 4
            let sepH = max(1.0 / max(traitCollection.displayScale, 1.0), 0.5)
            let sepGapBottom: CGFloat = 2
            let stripH: CGFloat = 40
            let stripHPadding: CGFloat = 6
            let icon: CGFloat = 22
            let chev: CGFloat = 14
            let gap: CGFloat = 4

            let text = bodyLabel.text ?? ""
            let font = bodyLabel.font ?? UIFont.systemFont(ofSize: 15)
            let labelText = actionsLabel.text ?? "Leave a Comment"
            let lw = (labelText as NSString).size(withAttributes: [.font: actionsLabel.font ?? UIFont.systemFont(ofSize: 14)]).width
            let stripIntrinsic = stripHPadding * 2 + icon + gap + ceil(lw) + gap + chev

            let textMaxWProbe = max(40, maxCardW - padX - timeTrailingInset - timeWMax - gapTextTime)
            let probeRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
            let bubbleW = min(maxCardW, max(stripIntrinsic, padX + usedTextW + gapTextTime + timeWMax + timeTrailingInset))

            let textMaxW = max(40, bubbleW - padX - timeTrailingInset - timeWMax - gapTextTime)
            let textRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let textH = ceil(textRect.height)
            let contentBlockH = max(textH, timeH)
            let bubbleH = padTop + contentBlockH + sepGapTop + sepH + sepGapBottom + stripH + padBottom

            postBubble.frame = CGRect(x: side, y: LayoutMetrics.spacingAboveCard, width: bubbleW, height: bubbleH)

            bodyLabel.frame = CGRect(x: padX, y: padTop, width: textMaxW, height: textH)

            timeLabel.sizeToFit()
            let measuredTw = max(ceil(timeLabel.intrinsicContentSize.width), ceil(timeLabel.bounds.width))
            var tw = min(timeWMax, measuredTw + 4)
            let maxTw = bubbleW - padX - timeTrailingInset
            tw = min(tw, max(20, maxTw))
            let timeX = max(padX, bubbleW - timeTrailingInset - tw)
            let timeY = padTop + contentBlockH - timeH
            timeLabel.frame = CGRect(x: timeX, y: timeY, width: tw, height: timeH)

            let sepY = padTop + contentBlockH + sepGapTop
            postDivider.frame = CGRect(x: padX, y: sepY, width: bubbleW - padX * 2, height: sepH)

            let actionY = sepY + sepH + sepGapBottom
            actionsRow.frame = CGRect(x: 0, y: actionY, width: bubbleW, height: stripH)
            actionsIcon.frame = CGRect(x: stripHPadding, y: (stripH - icon) / 2, width: icon, height: icon)
            actionsChevron.frame = CGRect(x: bubbleW - stripHPadding - chev, y: (stripH - chev) / 2, width: chev, height: chev)
            actionsLabel.frame = CGRect(
                x: actionsIcon.frame.maxX + gap,
                y: 0,
                width: max(0, actionsChevron.frame.minX - gap - (actionsIcon.frame.maxX + gap)),
                height: stripH
            )

            spoilerOverlay.frame = postBubble.frame
        } else {
            bubble.isHidden = false
            postBubble.isHidden = true

            let x: CGFloat = side
            let bw = maxCardW
            let textInset = LayoutMetrics.announcementTextSideInset
            let textContentW = bw - textInset * 2
            let imgSide = LayoutMetrics.announcementImageSideInset

            let hasImage = !announcementImageView.isHidden && announcementImageView.image != nil
            var y: CGFloat = hasImage ? imgSide : LayoutMetrics.announcementInnerTop
            if hasImage {
                let ih = LayoutMetrics.announcementImageHeight
                announcementImageView.frame = CGRect(x: imgSide, y: y, width: bw - imgSide * 2, height: ih)
                y = announcementImageView.frame.maxY + LayoutMetrics.announcementImageBottomGap
            } else {
                announcementImageView.frame = .zero
            }

            let titleH = titleLabel.sizeThatFits(CGSize(width: textContentW, height: 200)).height
            titleLabel.frame = CGRect(x: textInset, y: y, width: textContentW, height: ceil(titleH))
            y = titleLabel.frame.maxY + LayoutMetrics.titleBodyGap

            let bodyText = bodyLabel.text ?? ""
            let bodyRect = (bodyText as NSString).boundingRect(
                with: CGSize(width: textContentW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: bodyLabel.font ?? UIFont.systemFont(ofSize: 15)],
                context: nil
            )
            let bh = ceil(bodyRect.height)
            bodyLabel.frame = CGRect(x: textInset, y: y, width: textContentW, height: max(1, bh))
            y = bodyLabel.frame.maxY + LayoutMetrics.bodyBottomGap

            if !linkButton.isHidden {
                linkButton.titleLabel?.numberOfLines = 2
                let linkSize = linkButton.sizeThatFits(CGSize(width: textContentW, height: 500))
                linkButton.frame = CGRect(x: textInset, y: y, width: textContentW, height: ceil(linkSize.height))
                y = linkButton.frame.maxY + LayoutMetrics.linkBottomGap
            } else {
                linkButton.frame = .zero
            }

            let annInset = LayoutMetrics.announcementTextSideInset
            let timeTrailingInset = LayoutMetrics.announcementTimeTrailingInset
            let footerGap = LayoutMetrics.footerLocationTimeGap
            let footerH = LayoutMetrics.footerRowHeight

            timeLabel.sizeToFit()
            let timeMeasured = max(ceil(timeLabel.intrinsicContentSize.width), ceil(timeLabel.bounds.width))
            let timeRightX = bw - annInset - timeTrailingInset
            var tw = min(120, timeMeasured + 4)
            if !locationButton.isHidden {
                tw = min(tw, max(44, timeRightX - annInset - footerGap - 48))
            } else {
                tw = min(tw, max(44, timeRightX - annInset))
            }
            let timeX = timeRightX - tw

            if !locationButton.isHidden {
                let locMaxW = max(40, timeX - annInset - footerGap)
                locationButton.titleLabel?.numberOfLines = 1
                locationButton.contentHorizontalAlignment = .left
                locationButton.frame = CGRect(x: annInset, y: y, width: locMaxW, height: footerH)
                timeLabel.frame = CGRect(x: timeX, y: y, width: tw, height: footerH)
            } else {
                locationButton.frame = .zero
                timeLabel.frame = CGRect(x: timeX, y: y, width: tw, height: footerH)
            }

            y += footerH + LayoutMetrics.footerBottomPadding

            bubble.frame = CGRect(x: x, y: LayoutMetrics.spacingAboveCard, width: bw, height: y)

            spoilerOverlay.frame = .zero
        }
    }

    func configure(
        message: CommunityMessage,
        announcementIsSaved: Bool,
        spoiler: CommunityChatModel.SpoilerDecision?,
        spoilerIsRevealed: Bool
    ) {
        self.message = message
        self.announcementIsSaved = announcementIsSaved
        self.spoilerDecision = spoiler
        self.spoilerIsRevealed = spoilerIsRevealed
        switch message.kind {
        case .post:
            if bodyLabel.superview !== postBubble { postBubble.addSubview(bodyLabel) }
            if timeLabel.superview !== postBubble { postBubble.addSubview(timeLabel) }
            titleLabel.isHidden = true
            bodyLabel.text = message.text
            linkButton.isHidden = true
            locationButton.isHidden = true
            announcementImageView.isHidden = true
            announcementImageView.image = nil
            timeLabel.text = Self.shortTime(message.createdAt)
        case .announcement:
            if bodyLabel.superview !== bubble { bubble.addSubview(bodyLabel) }
            if timeLabel.superview !== bubble { bubble.addSubview(timeLabel) }
            titleLabel.isHidden = false
            let a = message.announcement
            titleLabel.text = "Анонс" + (a?.title.isEmpty == false ? ": \(a!.title)" : "")
            bodyLabel.text = (a?.details?.isEmpty == false ? a!.details : message.text)
            timeLabel.text = a.map { Self.dateTime($0.date) } ?? Self.shortTime(message.createdAt)

            if let url = CommunityStore.announcementImageURL(fileName: a?.imageFileName),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                announcementImageView.isHidden = false
                announcementImageView.image = img
            } else {
                announcementImageView.isHidden = true
                announcementImageView.image = nil
            }

            if let link = a?.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
                linkButton.isHidden = false
                linkButton.setTitle("Ссылка: \(link)", for: .normal)
            } else {
                linkButton.isHidden = true
            }

            if let loc = a?.location {
                locationButton.isHidden = false
                let name = (loc.title?.isEmpty == false ? loc.title! : "Точка на карте")
                locationButton.setTitle("Место: \(name)", for: .normal)
            } else {
                locationButton.isHidden = true
            }

            bubble.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
        }
        applyMediaLibraryChromeColors()
        applySpoilerOverlay()
        setNeedsLayout()
    }

    private func applySpoilerOverlay() {
        guard let spoilerDecision else {
            spoilerOverlay.isHidden = true
            return
        }
        spoilerOverlay.title = spoilerDecision.title
        spoilerOverlay.subtitle = spoilerDecision.subtitle
        spoilerOverlay.isHidden = spoilerIsRevealed
    }

    @objc private func actionsTapped() {
        guard let message, message.kind == .post else { return }
        onOpenComments?(message)
    }

    @objc private func linkTapped() {
        guard let link = message?.announcement?.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else { return }
        let urlString = link.hasPrefix("http://") || link.hasPrefix("https://") ? link : "https://\(link)"
        guard let url = URL(string: urlString) else { return }
        onOpenLink?(url)
    }

    @objc private func locationTapped() {
        guard let loc = message?.announcement?.location else { return }
        onOpenLocation?(loc)
    }

    private static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private static func dateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: date)
    }
}

@available(iOS 13.0, *)
extension CommunityMessageCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard message?.kind == .announcement, let msg = message else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu(children: []) }
            if self.announcementIsSaved {
                return UIMenu(children: [
                    UIAction(title: "Уже в моих анонсах", attributes: .disabled) { _ in }
                ])
            }
            let chrome = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: self.traitCollection)
            let bookmarkImage = UIImage(systemName: "bookmark")?.withTintColor(chrome, renderingMode: .alwaysOriginal)
            return UIMenu(children: [
                UIAction(title: "В мои анонсы", image: bookmarkImage) { [weak self] _ in
                    self?.onSaveAnnouncement?(msg)
                }
            ])
        }
    }
}

