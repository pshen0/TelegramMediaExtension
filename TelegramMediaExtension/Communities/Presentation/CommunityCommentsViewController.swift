import Combine
import UIKit

final class CommunityCommentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    private let store = CommunityStore.shared
    private let message: CommunityMessage

    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let inputField = UITextView()
    private let sendButton = UIButton(type: .system)

    private var comments: [CommunityComment] = []
    private var mediaLibraryChromeObserver: NSObjectProtocol?

    init(message: CommunityMessage) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Комментарии"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        store.loadIfNeeded()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .systemGroupedBackground
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tableView.estimatedRowHeight = 72
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseId)

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

        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
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

        content.addSubview(inputField)
        content.addSubview(sendButton)

        sendButton.pinRight(to: content, 10)
        sendButton.pinCenterY(to: inputField.centerYAnchor)
        sendButton.setWidth(36)
        sendButton.setHeight(36)

        inputField.pinTop(to: content, 8)
        inputField.pinBottom(to: content, 8)
        inputField.pinLeft(to: content, 12)
        inputField.pinRight(to: sendButton.leadingAnchor, 8)
        inputField.setHeight(mode: .grOE, 38)

        applyMediaLibraryChromeToSendButton()
        mediaLibraryChromeObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyMediaLibraryChromeToSendButton()
        }

        bind()
        reloadAndScroll(animated: false)
    }

    deinit {
        if let mediaLibraryChromeObserver {
            NotificationCenter.default.removeObserver(mediaLibraryChromeObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToSendButton()
    }

    private func applyMediaLibraryChromeToSendButton() {
        sendButton.tintColor = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
    }

    private func bind() {
        store.$comments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAndScroll(animated: true)
            }
            .store(in: &cancellables)
    }

    private func reloadAndScroll(animated: Bool) {
        comments = store.comments(for: message.id)
        tableView.reloadData()
        scrollToBottom(animated: animated)
    }

    private func scrollToBottom(animated: Bool) {
        guard comments.count > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: comments.count - 1, section: 0), at: .bottom, animated: animated)
    }

    @objc private func sendTapped() {
        let text = inputField.text ?? ""
        store.addComment(messageId: message.id, text: text)
        inputField.text = ""
        textViewDidChange(inputField)
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommentCell.height(for: comments[indexPath.row], tableWidth: tableView.bounds.width)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseId, for: indexPath) as! CommentCell
        cell.configure(comment: comments[indexPath.row])
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

private final class CommentCell: UITableViewCell {
    static let reuseId = "CommentCell"

    private let bubble = UIView()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        bubble.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { bubble.layer.cornerCurve = .continuous }
        bubble.backgroundColor = .secondarySystemBackground
        contentView.addSubview(bubble)

        bodyLabel.font = TMETheme.Fonts.body(15)
        bodyLabel.numberOfLines = 0
        bodyLabel.textColor = .label

        timeLabel.font = TMETheme.Fonts.body(11)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right

        bubble.addSubview(bodyLabel)
        bubble.addSubview(timeLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    static func height(for comment: CommunityComment, tableWidth: CGFloat) -> CGFloat {
        let w = max(0, tableWidth)
        let side: CGFloat = 16
        let maxCardW = w - side * 2
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
        let maxCardW = w - side * 2
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
    }

    func configure(comment: CommunityComment) {
        bodyLabel.text = comment.text
        timeLabel.text = Self.shortTime(comment.createdAt)
        setNeedsLayout()
    }

    private static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

