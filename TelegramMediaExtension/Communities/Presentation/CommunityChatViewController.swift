import Combine
import SafariServices
import UIKit

final class CommunityChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    private let store = CommunityStore.shared
    private let communityId: UUID
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let inputField = UITextView()
    private let sendButton = UIButton(type: .system)
    private let announcementButton = UIButton(type: .system)

    private var messages: [CommunityMessage] = []

    init(communityId: UUID) {
        self.communityId = communityId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        store.loadIfNeeded()
        title = store.communities.first(where: { $0.id == communityId })?.title ?? "Сообщество"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.estimatedRowHeight = 140
        tableView.register(CommunityMessageCell.self, forCellReuseIdentifier: CommunityMessageCell.reuseId)

        view.addSubview(tableView)
        view.addSubview(inputContainer)

        tableView.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
        tableView.pinLeft(to: view)
        tableView.pinRight(to: view)
        tableView.pinBottom(to: inputContainer.topAnchor)

        inputContainer.pinLeft(to: view)
        inputContainer.pinRight(to: view)
        inputContainer.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor)

        let content = inputContainer.contentView
        announcementButton.setImage(UIImage(systemName: "sparkle"), for: .normal)
        announcementButton.tintColor = TMETheme.Colors.accent
        announcementButton.accessibilityLabel = "Новый анонс"
        announcementButton.addTarget(self, action: #selector(newAnnouncementTapped), for: .touchUpInside)

        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = TMETheme.Colors.accent
        sendButton.accessibilityLabel = "Отправить"
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputField.font = TMETheme.Fonts.body(16)
        inputField.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.7)
        inputField.layer.cornerRadius = 18
        if #available(iOS 13.0, *) {
            inputField.layer.cornerCurve = .continuous
        }
        inputField.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        inputField.isScrollEnabled = false
        inputField.delegate = self

        content.addSubview(announcementButton)
        content.addSubview(inputField)
        content.addSubview(sendButton)

        announcementButton.pinLeft(to: content, 10)
        announcementButton.pinCenterY(to: inputField.centerYAnchor)
        announcementButton.setWidth(34)
        announcementButton.setHeight(34)

        sendButton.pinRight(to: content, 10)
        sendButton.pinCenterY(to: inputField.centerYAnchor)
        sendButton.setWidth(36)
        sendButton.setHeight(36)

        inputField.pinTop(to: content, 8)
        inputField.pinBottom(to: content, 8)
        inputField.pinLeft(to: announcementButton.trailingAnchor, 8)
        inputField.pinRight(to: sendButton.leadingAnchor, 8)
        inputField.setHeight(mode: .grOE, 38)

        bind()
        reloadMessagesAndScroll(animated: false)
    }

    private func bind() {
        store.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reloadMessagesAndScroll(animated: true)
            }
            .store(in: &cancellables)

        store.$savedAnnouncements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    private func reloadMessagesAndScroll(animated: Bool) {
        messages = store.messages(for: communityId)
        tableView.reloadData()
        scrollToBottom(animated: animated)
    }

    private func scrollToBottom(animated: Bool) {
        guard messages.count > 0 else { return }
        let ip = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: animated)
    }

    @objc private func sendTapped() {
        let text = inputField.text ?? ""
        store.addPost(communityId: communityId, text: text)
        inputField.text = ""
        textViewDidChange(inputField)
    }

    @objc private func newAnnouncementTapped() {
        let vc = NewAnnouncementViewController(communityId: communityId)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommunityMessageCell.height(for: messages[indexPath.row], tableWidth: tableView.bounds.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommunityMessageCell.reuseId, for: indexPath) as! CommunityMessageCell
        let msg = messages[indexPath.row]
        let saved = store.savedAnnouncements.contains(where: { $0.sourceMessageId == msg.id })
        cell.configure(message: msg, announcementIsSaved: saved)
        cell.onSaveAnnouncement = { [weak self] msg in
            self?.store.saveAnnouncementFromMessage(msg)
        }
        cell.onOpenComments = { [weak self] msg in
            guard let self else { return }
            self.navigationController?.pushViewController(CommunityCommentsViewController(message: msg), animated: true)
        }
        cell.onOpenLink = { [weak self] url in
            guard let self else { return }
            let vc = SFSafariViewController(url: url)
            self.present(vc, animated: true)
        }
        cell.onOpenLocation = { loc in
            let url = YandexMapsURL.point(latitude: loc.latitude, longitude: loc.longitude)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        return cell
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        textView.isScrollEnabled = size.height > 120
        view.setNeedsLayout()
        UIView.performWithoutAnimation {
            self.inputContainer.layoutIfNeeded()
        }
    }
}

private final class CommunityMessageCell: UITableViewCell {
    static let reuseId = "CommunityMessageCell"

    var onSaveAnnouncement: ((CommunityMessage) -> Void)?
    var onOpenComments: ((CommunityMessage) -> Void)?
    var onOpenLink: ((URL) -> Void)?
    var onOpenLocation: ((CommunityLocation) -> Void)?
    private var message: CommunityMessage?
    private var announcementIsSaved = false

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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        for v in [bubble, postBubble] {
            v.layer.cornerRadius = 16
            if #available(iOS 13.0, *) { v.layer.cornerCurve = .continuous }
        }
        bubble.backgroundColor = .secondarySystemBackground
        postBubble.backgroundColor = .secondarySystemBackground

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
        actionsIcon.tintColor = TMETheme.Colors.accent
        actionsIcon.contentMode = .scaleAspectFit

        actionsLabel.font = TMETheme.Fonts.body(14)
        actionsLabel.textColor = TMETheme.Colors.accent
        actionsLabel.text = "Leave a Comment"

        actionsChevron.image = UIImage(systemName: "chevron.right")
        actionsChevron.tintColor = TMETheme.Colors.accent.withAlphaComponent(0.75)
        actionsChevron.contentMode = .scaleAspectFit

        linkButton.titleLabel?.font = TMETheme.Fonts.body(13)
        linkButton.setTitleColor(TMETheme.Colors.accent, for: .normal)
        linkButton.contentHorizontalAlignment = .left
        linkButton.addTarget(self, action: #selector(linkTapped), for: .touchUpInside)

        locationButton.titleLabel?.font = TMETheme.Fonts.body(13)
        locationButton.setTitleColor(TMETheme.Colors.accent, for: .normal)
        locationButton.contentHorizontalAlignment = .left
        locationButton.addTarget(self, action: #selector(locationTapped), for: .touchUpInside)

        timeLabel.font = TMETheme.Fonts.body(11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right

        contentView.addSubview(bubble)
        contentView.addSubview(postBubble)

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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func height(for message: CommunityMessage, tableWidth: CGFloat) -> CGFloat {
        let w = max(0, tableWidth)
        let side: CGFloat = 16
        let maxCardW = w - side * 2
        if message.kind == .post {
            let text = message.text
            let padX: CGFloat = 12
            let padTop: CGFloat = 10
            let padBottom: CGFloat = 10
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let sepGapTop: CGFloat = 8
            let sepH: CGFloat = 1
            let sepGapBottom: CGFloat = 4
            let stripH: CGFloat = 40
            let stripHPadding: CGFloat = 12
            let icon: CGFloat = 22
            let chev: CGFloat = 14
            let gap: CGFloat = 8
            let lw = ceil(("Leave a Comment" as NSString).size(withAttributes: [.font: TMETheme.Fonts.body(14)]).width)
            let stripIntrinsic = stripHPadding * 2 + icon + gap + lw + gap + chev

            let textMaxWProbe = max(40, maxCardW - padX * 2 - timeWMax - 6)
            let probeRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(15)],
                context: nil
            )
            let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
            let bubbleW = min(maxCardW, max(stripIntrinsic, padX * 2 + usedTextW + 6 + timeWMax))
            let textMaxW = max(40, bubbleW - padX * 2 - timeWMax - 6)
            let textRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(15)],
                context: nil
            )
            let textH = ceil(textRect.height)
            let contentBlockH = max(textH, timeH)
            let bubbleH = padTop + contentBlockH + sepGapTop + sepH + sepGapBottom + stripH + padBottom

            return 6 + bubbleH + 6
        }

        var y: CGFloat = 10
        let bw = maxCardW
        let a = message.announcement
        let imgExists: Bool = {
            guard let name = a?.imageFileName, let u = CommunityStore.announcementImageURL(fileName: name) else { return false }
            return FileManager.default.fileExists(atPath: u.path)
        }()
        if imgExists { y += 180 + 10 }

        let title = "Анонс" + (a?.title.isEmpty == false ? ": \(a!.title)" : "")
        let titleH = ceil((title as NSString).boundingRect(
            with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.titleSemibold(15)],
            context: nil
        ).height)
        y += titleH + 8

        let bodyText = (a?.details?.isEmpty == false ? a!.details : message.text) ?? ""
        let bh = ceil((bodyText as NSString).boundingRect(
            with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.body(15)],
            context: nil
        ).height)
        y += max(1, bh) + 10

        if let link = a?.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
            let t = "Ссылка: \(link)"
            y += ceil((t as NSString).boundingRect(
                with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(13)],
                context: nil
            ).height) + 6
        }
        if a?.location != nil {
            y += 28 + 6
        }
        y += 18 + 10
        return 6 + y
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let message else { return }
        let w = contentView.bounds.width
        let side: CGFloat = 16
        let maxCardW = w - side * 2

        if message.kind == .post {
            bubble.isHidden = true
            postBubble.isHidden = false

            let padX: CGFloat = 12
            let padTop: CGFloat = 10
            let padBottom: CGFloat = 10
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let sepGapTop: CGFloat = 8
            let sepH = max(1.0 / max(traitCollection.displayScale, 1.0), 0.5)
            let sepGapBottom: CGFloat = 4
            let stripH: CGFloat = 40
            let stripHPadding: CGFloat = 12
            let icon: CGFloat = 22
            let chev: CGFloat = 14
            let gap: CGFloat = 8

            let text = bodyLabel.text ?? ""
            let font = bodyLabel.font ?? UIFont.systemFont(ofSize: 15)
            let labelText = actionsLabel.text ?? "Leave a Comment"
            let lw = (labelText as NSString).size(withAttributes: [.font: actionsLabel.font ?? UIFont.systemFont(ofSize: 14)]).width
            let stripIntrinsic = stripHPadding * 2 + icon + gap + ceil(lw) + gap + chev

            let textMaxWProbe = max(40, maxCardW - padX * 2 - timeWMax - 6)
            let probeRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxWProbe, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let usedTextW = min(textMaxWProbe, max(ceil(probeRect.width), 1))
            let bubbleW = min(maxCardW, max(stripIntrinsic, padX * 2 + usedTextW + 6 + timeWMax))

            let textMaxW = max(40, bubbleW - padX * 2 - timeWMax - 6)
            let textRect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxW, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            let textH = ceil(textRect.height)
            let contentBlockH = max(textH, timeH)
            let bubbleH = padTop + contentBlockH + sepGapTop + sepH + sepGapBottom + stripH + padBottom

            postBubble.frame = CGRect(x: side, y: 6, width: bubbleW, height: bubbleH)

            bodyLabel.frame = CGRect(x: padX, y: padTop, width: textMaxW, height: textH)

            timeLabel.sizeToFit()
            let tw = min(timeWMax, ceil(timeLabel.bounds.width) + 2)
            let timeX = bubbleW - padX - tw
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
        } else {
            bubble.isHidden = false
            postBubble.isHidden = true

            var y: CGFloat = 10
            let x: CGFloat = side
            let bw = maxCardW

            let hasImage = !announcementImageView.isHidden && announcementImageView.image != nil
            if hasImage {
                let ih: CGFloat = 180
                announcementImageView.frame = CGRect(x: 10, y: y, width: bw - 20, height: ih)
                y = announcementImageView.frame.maxY + 10
            } else {
                announcementImageView.frame = .zero
            }

            let titleH = titleLabel.sizeThatFits(CGSize(width: bw - 24, height: 200)).height
            titleLabel.frame = CGRect(x: 12, y: y, width: bw - 24, height: ceil(titleH))
            y = titleLabel.frame.maxY + 8

            let bodyText = bodyLabel.text ?? ""
            let bodyRect = (bodyText as NSString).boundingRect(
                with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: bodyLabel.font ?? UIFont.systemFont(ofSize: 15)],
                context: nil
            )
            let bh = ceil(bodyRect.height)
            bodyLabel.frame = CGRect(x: 12, y: y, width: bw - 24, height: max(1, bh))
            y = bodyLabel.frame.maxY + 10

            if !linkButton.isHidden {
                linkButton.titleLabel?.numberOfLines = 2
                let linkSize = linkButton.sizeThatFits(CGSize(width: bw - 24, height: 120))
                linkButton.frame = CGRect(x: 12, y: y, width: bw - 24, height: ceil(linkSize.height))
                y = linkButton.frame.maxY + 6
            } else {
                linkButton.frame = .zero
            }

            if !locationButton.isHidden {
                let locSize = locationButton.sizeThatFits(CGSize(width: bw - 24, height: 120))
                locationButton.frame = CGRect(x: 12, y: y, width: bw - 24, height: ceil(locSize.height))
                y = locationButton.frame.maxY + 6
            } else {
                locationButton.frame = .zero
            }

            let timeHAnn: CGFloat = 18
            timeLabel.sizeToFit()
            let tw = min(bw - 24, timeLabel.bounds.width + 6)
            timeLabel.frame = CGRect(x: x + bw - 12 - tw, y: y, width: tw, height: timeHAnn)
            y = timeLabel.frame.maxY + 10

            bubble.frame = CGRect(x: x, y: 6, width: bw, height: y)
        }
    }

    func configure(message: CommunityMessage, announcementIsSaved: Bool) {
        self.message = message
        self.announcementIsSaved = announcementIsSaved
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
        setNeedsLayout()
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
            return UIMenu(children: [
                UIAction(title: "В мои анонсы", image: UIImage(systemName: "bookmark")) { [weak self] _ in
                    self?.onSaveAnnouncement?(msg)
                }
            ])
        }
    }
}
