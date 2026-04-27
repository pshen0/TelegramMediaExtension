import Combine
import UIKit

/// Комментарии к посту или вложенное обсуждение под одним комментарием (`threadParentCommentId`).
final class CommunityCommentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
    private enum InputBarMetrics {
        static let sideDiameter: CGFloat = 32
        static let barVerticalMargin: CGFloat = 6
        static let pillInnerVerticalPadding: CGFloat = 5
        static let minTextHeight: CGFloat = 20
        static var compactPillHeight: CGFloat { minTextHeight + pillInnerVerticalPadding * 2 }
        static let multilinePillMaxCornerRadius: CGFloat = 20
        static let gapLastCommentToInputBar: CGFloat = 10
        static let scrollPinnedBottomSlack: CGFloat = 48
        /// Доп. отступ контента под размытый навбар (как был `contentInset.top` при привязке к safe area).
        static let tableTopExtraPadding: CGFloat = 8
    }

    private let store = CommunityStore.shared
    /// Корневое сообщество-сообщение (пост), к которому относится цепочка комментариев.
    private let rootMessage: CommunityMessage
    /// `nil` — список комментариев к посту; иначе ответы внутри треда этого комментария.
    private let threadParentCommentId: UUID?

    /// Цепочка только из трёх экранов: сообщество → комментарии → обсуждение; глубже переходов нет.
    private var allowsOpeningNestedThread: Bool { threadParentCommentId == nil }

    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let contextHeader = ThreadContextHeaderView()
    private var lastContextHeaderSize: CGSize = .zero
    private var isUpdatingContextHeader = false
    private let inputContainer = UIView()
    private let inputPill = UIView()
    private let inputField = UITextView()
    private let inputPlaceholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private var inputPillHeightConstraint: NSLayoutConstraint!
    private var textViewHeightConstraint: NSLayoutConstraint!

    private var comments: [CommunityComment] = []
    private var mediaLibraryChromeObserver: NSObjectProtocol?
    private var keyboardFrameObserver: NSObjectProtocol?
    private var keyboardHideObserver: NSObjectProtocol?
    private var cachedKeyboardBottomOverlap: CGFloat = 0
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    init(message: CommunityMessage, threadParentCommentId: UUID? = nil) {
        self.rootMessage = message
        self.threadParentCommentId = threadParentCommentId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        title = threadParentCommentId == nil ? "Комментарии" : "Обсуждение"

        store.loadIfNeeded()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = .zero
        tableView.estimatedRowHeight = 72
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseId)
        contextHeader.backgroundColor = .clear
        tableView.tableHeaderView = contextHeader

        view.addSubview(tableView)
        view.addSubview(inputContainer)
        keyboardDismissOnTapOutside.attach(to: view)

        tableView.pinTop(to: view.topAnchor)
        tableView.pinLeft(to: view)
        tableView.pinRight(to: view)
        tableView.pinBottom(to: view)

        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.backgroundColor = .clear
        inputContainer.isOpaque = false
        inputContainer.isUserInteractionEnabled = true
        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])

        let content = inputContainer

        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.accessibilityLabel = "Отправить"
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputPill.translatesAutoresizingMaskIntoConstraints = false
        inputPill.clipsToBounds = true
        if #available(iOS 13.0, *) {
            inputPill.layer.cornerCurve = .continuous
        }
        inputPill.isOpaque = true
        inputPill.layer.borderWidth = 1.0 / UIScreen.main.scale

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.font = TMETheme.Fonts.body(16)
        inputField.backgroundColor = .clear
        inputField.textColor = .label
        inputField.textContainerInset = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        inputField.textContainer.lineFragmentPadding = 0
        inputField.isScrollEnabled = false
        inputField.delegate = self

        inputPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        inputPlaceholderLabel.text = "Комментарий"
        inputPlaceholderLabel.font = inputField.font
        inputPlaceholderLabel.textColor = .placeholderText
        inputPlaceholderLabel.isUserInteractionEnabled = false

        content.addSubview(inputPill)
        content.addSubview(sendButton)
        inputPill.addSubview(inputPlaceholderLabel)
        inputPill.addSubview(inputField)

        let side = InputBarMetrics.sideDiameter
        let gap: CGFloat = 8
        inputPillHeightConstraint = inputPill.heightAnchor.constraint(equalToConstant: InputBarMetrics.compactPillHeight)
        textViewHeightConstraint = inputField.heightAnchor.constraint(equalToConstant: InputBarMetrics.minTextHeight)

        NSLayoutConstraint.activate([
            inputPill.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            inputPill.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -gap),
            inputPill.topAnchor.constraint(equalTo: content.topAnchor, constant: InputBarMetrics.barVerticalMargin),
            inputPillHeightConstraint,
            content.bottomAnchor.constraint(equalTo: inputPill.bottomAnchor, constant: InputBarMetrics.barVerticalMargin),

            sendButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputPill.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: side),
            sendButton.heightAnchor.constraint(equalToConstant: side),

            inputField.leadingAnchor.constraint(equalTo: inputPill.leadingAnchor, constant: 10),
            inputField.topAnchor.constraint(equalTo: inputPill.topAnchor, constant: InputBarMetrics.pillInnerVerticalPadding),
            inputField.trailingAnchor.constraint(equalTo: inputPill.trailingAnchor, constant: -10),
            textViewHeightConstraint,

            inputPlaceholderLabel.leadingAnchor.constraint(equalTo: inputField.leadingAnchor, constant: 8),
            inputPlaceholderLabel.centerYAnchor.constraint(equalTo: inputField.centerYAnchor)
        ])

        applyMediaLibraryChromeToInputBar()
        mediaLibraryChromeObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyMediaLibraryChromeToInputBar()
            self?.applyCommentsNavigationAppearance()
        }

        bind()
        reloadAndScroll(animated: false)
        updateContextHeader()
        updateContextHeaderLayoutIfNeeded()

        view.layoutIfNeeded()
        textViewDidChange(inputField)
        updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: false)

        keyboardFrameObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let fromFrame = self.keyboardOverlapHeight(from: note)
            let fromGuide = max(0, self.view.bounds.maxY - self.view.keyboardLayoutGuide.layoutFrame.minY)
            let overlap = max(fromFrame, fromGuide)
            self.cachedKeyboardBottomOverlap = overlap > 0.5 ? overlap : 0
            self.animateWithKeyboardNotification(
                note,
                animations: {
                    self.updateCommentsTableBottomInset(keyboardOverlap: overlap, adjustScroll: true, deferGrowingScroll: true)
                },
                completion: {
                    guard overlap > 0.5 else { return }
                    self.scrollCommentsToLastRowRespectingInset(animated: false)
                }
            )
        }

        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.cachedKeyboardBottomOverlap = 0
            self.updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: true, deferGrowingScroll: false)
        }
    }

    deinit {
        if let mediaLibraryChromeObserver {
            NotificationCenter.default.removeObserver(mediaLibraryChromeObserver)
        }
        if let keyboardFrameObserver {
            NotificationCenter.default.removeObserver(keyboardFrameObserver)
        }
        if let keyboardHideObserver {
            NotificationCenter.default.removeObserver(keyboardHideObserver)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCommentsTableTopInset()
        updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        updateInputPillCornerRadius()
        updateContextHeaderLayoutIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCommentsTableTopInset()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyCommentsNavigationAppearance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreCommentsNavigationAppearance()
    }

    private func updateInputPillCornerRadius() {
        let h = inputPill.bounds.height
        guard h > 1 else { return }
        let textH = textViewHeightConstraint.constant
        let singleLine = textH <= InputBarMetrics.minTextHeight + 0.5
        if singleLine {
            inputPill.layer.cornerRadius = h * 0.5
        } else {
            inputPill.layer.cornerRadius = min(InputBarMetrics.multilinePillMaxCornerRadius, h * 0.5)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToInputBar()
        applyCommentsNavigationAppearance()
    }

    /// Как у корневого меню и форм медиатеки: стандартный материал с размытием (`configureWithDefaultBackground`).
    private func commentsNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        return appearance
    }

    private func applyCommentsNavigationAppearance() {
        let appearance = commentsNavigationBarAppearance()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }
        let accent = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        navigationController?.navigationBar.tintColor = accent
    }

    private func restoreCommentsNavigationAppearance() {
        navigationItem.standardAppearance = nil
        navigationItem.scrollEdgeAppearance = nil
        navigationItem.compactAppearance = nil
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = nil
        }
    }

    /// Как список «Сообщества»: контент уходит под навбар и виден через размытие.
    private func updateCommentsTableTopInset() {
        let newTop = view.safeAreaInsets.top + InputBarMetrics.tableTopExtraPadding
        let oldTop = tableView.contentInset.top
        guard abs(newTop - oldTop) > 0.25 else { return }
        let delta = newTop - oldTop
        var inset = tableView.contentInset
        inset.top = newTop
        tableView.contentInset = inset
        var ind = tableView.verticalScrollIndicatorInsets
        ind.top = newTop
        tableView.verticalScrollIndicatorInsets = ind
        var y = tableView.contentOffset.y + delta
        let maxY = max(
            0,
            tableView.contentSize.height - tableView.bounds.height + tableView.contentInset.bottom
        )
        y = min(max(0, y), maxY)
        tableView.contentOffset.y = y
    }

    private func applyMediaLibraryChromeToInputBar() {
        let accent = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        let d = InputBarMetrics.sideDiameter
        let r = d / 2
        var sendCfg = UIButton.Configuration.plain()
        sendCfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        sendCfg.image = UIImage(systemName: "paperplane.fill")
        sendCfg.baseForegroundColor = .white
        sendCfg.background.backgroundColor = accent
        sendCfg.background.cornerRadius = r
        sendButton.configuration = sendCfg

        inputPill.backgroundColor = .secondarySystemGroupedBackground
        inputPill.layer.borderColor = UIColor.separator.cgColor
    }

    private func animateWithKeyboardNotification(
        _ note: Notification,
        animations: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        let userInfo = note.userInfo ?? [:]
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? 7
        let options = UIView.AnimationOptions(rawValue: curve << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.view.layoutIfNeeded()
            animations()
        }, completion: { _ in
            completion?()
        })
    }

    private func keyboardOverlapHeight(from note: Notification) -> CGFloat {
        guard let rect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }
        var best = max(0, view.bounds.maxY - view.convert(rect, from: nil).minY)
        if let win = view.window {
            best = max(best, max(0, view.bounds.maxY - view.convert(rect, from: win).minY))
            best = max(best, max(0, view.bounds.maxY - view.convert(rect, from: win.screen.coordinateSpace).minY))
        }
        return best
    }

    private func keyboardOverlapFromInputBarLayout() -> CGFloat {
        max(0, view.bounds.maxY - inputContainer.frame.maxY)
    }

    private func keyboardOverlapFromKeyboardGuide() -> CGFloat {
        let lf = view.keyboardLayoutGuide.layoutFrame
        guard lf.height > 0.5 || lf.minY < view.bounds.maxY - 0.5 else { return 0 }
        return max(0, view.bounds.maxY - lf.minY)
    }

    private func updateCommentsTableBottomInset(
        keyboardOverlap: CGFloat? = nil,
        adjustScroll: Bool,
        deferGrowingScroll: Bool = false
    ) {
        view.layoutIfNeeded()
        let barH = inputContainer.bounds.height
        guard barH > 0 else { return }

        let fromLayout = keyboardOverlapFromInputBarLayout()
        let fromGuide = keyboardOverlapFromKeyboardGuide()
        let mergedLocal = max(fromLayout, fromGuide, cachedKeyboardBottomOverlap)
        let overlap: CGFloat
        if let k = keyboardOverlap {
            overlap = max(k, mergedLocal)
        } else {
            overlap = mergedLocal
        }
        let obscured = overlap + barH
        let gap = InputBarMetrics.gapLastCommentToInputBar
        let newBottom = obscured + gap

        let oldBottom = tableView.contentInset.bottom
        let delta = newBottom - oldBottom

        let oldMaxY = max(0, tableView.contentSize.height - tableView.bounds.height + oldBottom)
        let slack = InputBarMetrics.scrollPinnedBottomSlack
        let pinnedNearBottom = tableView.contentOffset.y >= oldMaxY - slack

        var inset = tableView.contentInset
        inset.bottom = newBottom
        tableView.contentInset = inset
        var ind = tableView.verticalScrollIndicatorInsets
        ind.bottom = inset.bottom
        tableView.verticalScrollIndicatorInsets = ind

        guard adjustScroll, abs(delta) > 0.5 else { return }

        let newMaxY = max(0, tableView.contentSize.height - tableView.bounds.height + newBottom)

        if delta > 0 {
            if deferGrowingScroll { return }
            if pinnedNearBottom {
                scrollCommentsToLastRowRespectingInset(animated: false)
                DispatchQueue.main.async { [weak self] in
                    self?.scrollCommentsToLastRowRespectingInset(animated: false)
                }
            } else {
                tableView.contentOffset.y = min(newMaxY, tableView.contentOffset.y + delta)
            }
            return
        }

        if pinnedNearBottom {
            tableView.contentOffset.y = newMaxY
        } else {
            var y = tableView.contentOffset.y + delta
            y = min(newMaxY, max(0, y))
            tableView.contentOffset.y = y
        }
    }

    private func scrollCommentsToLastRowRespectingInset(animated: Bool) {
        guard !comments.isEmpty else { return }
        let ip = IndexPath(row: comments.count - 1, section: 0)
        tableView.layoutIfNeeded()
        guard tableView.numberOfRows(inSection: 0) > ip.row else { return }
        tableView.scrollToRow(at: ip, at: .bottom, animated: animated)
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.comments.isEmpty else { return }
            let ip = IndexPath(row: self.comments.count - 1, section: 0)
            self.tableView.layoutIfNeeded()
            guard self.tableView.numberOfRows(inSection: 0) > ip.row else { return }
            self.tableView.scrollToRow(at: ip, at: .bottom, animated: false)
        }
    }

    private func bind() {
        store.$comments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadAndScroll(animated: true)
                self?.updateContextHeader()
                self?.updateContextHeaderLayoutIfNeeded()
            }
            .store(in: &cancellables)
    }

    private func reloadAndScroll(animated: Bool) {
        comments = store.comments(for: rootMessage.id, threadParentCommentId: threadParentCommentId)
        tableView.reloadData()
        scrollToBottom(animated: animated)
    }

    private func updateContextHeader() {
        if threadParentCommentId == nil {
            contextHeader.configureAsRootMessage(rootMessage)
            return
        }
        let parentId = threadParentCommentId!
        let allRootComments = store.comments(for: rootMessage.id, threadParentCommentId: nil)
        if let parent = allRootComments.first(where: { $0.id == parentId }) {
            contextHeader.configureAsParentComment(parent)
        } else {
            contextHeader.configureAsParentComment(
                CommunityComment(messageId: rootMessage.id, threadParentCommentId: nil, text: "Комментарий")
            )
        }
    }

    private func updateContextHeaderLayoutIfNeeded() {
        guard let header = tableView.tableHeaderView else { return }
        let w = tableView.bounds.width
        guard w > 0 else { return }
        guard !isUpdatingContextHeader else { return }

        let target = CGSize(width: w, height: UIView.layoutFittingCompressedSize.height)
        let fitted = header.systemLayoutSizeFitting(
            target,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let newSize = CGSize(width: w, height: ceil(fitted.height))
        let sizeChanged =
            abs(newSize.width - lastContextHeaderSize.width) > 0.5
            || abs(newSize.height - lastContextHeaderSize.height) > 0.5
        guard sizeChanged else { return }

        isUpdatingContextHeader = true
        lastContextHeaderSize = newSize
        header.frame = CGRect(origin: .zero, size: newSize)
        tableView.tableHeaderView = header
        isUpdatingContextHeader = false
    }

    private func scrollToBottom(animated: Bool) {
        updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        scrollCommentsToLastRowRespectingInset(animated: animated)
    }

    @objc private func sendTapped() {
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addComment(messageId: rootMessage.id, threadParentCommentId: threadParentCommentId, text: text)
        inputField.text = ""
        textViewDidChange(inputField)
    }

    // MARK: - UITableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommentCell.height(
            for: comments[indexPath.row],
            tableWidth: tableView.bounds.width,
            showsThreadChevron: allowsOpeningNestedThread
        )
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseId, for: indexPath) as! CommentCell
        cell.configure(comment: comments[indexPath.row], showsThreadChevron: allowsOpeningNestedThread)
        cell.applyThreadChrome()
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard allowsOpeningNestedThread else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        let c = comments[indexPath.row]
        let next = CommunityCommentsViewController(message: rootMessage, threadParentCommentId: c.id)
        navigationController?.pushViewController(next, animated: true)
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard textView === inputField else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
            self.scrollCommentsToLastRowRespectingInset(animated: false)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let trimmedEmpty = (textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        inputPlaceholderLabel.isHidden = !trimmedEmpty

        let w = max(1, textView.bounds.width)
        let fitted = textView.sizeThatFits(CGSize(width: w, height: CGFloat.greatestFiniteMagnitude))
        let maxTextBlock: CGFloat = 120
        let pad = InputBarMetrics.pillInnerVerticalPadding * 2
        let textBlockH = min(maxTextBlock, max(InputBarMetrics.minTextHeight, ceil(fitted.height)))
        textView.isScrollEnabled = fitted.height > maxTextBlock + 0.5

        textViewHeightConstraint.constant = textBlockH
        inputPillHeightConstraint.constant = textBlockH + pad

        view.setNeedsLayout()
        UIView.performWithoutAnimation {
            self.view.layoutIfNeeded()
            self.updateInputPillCornerRadius()
        }
        updateCommentsTableBottomInset(keyboardOverlap: nil, adjustScroll: true)
    }
}

// MARK: - Контекст сверху (пост / комментарий)

private final class ThreadContextHeaderView: UIView {
    private let badge = UILabel()
    private let bubble = UIView()
    private let textLabel = UILabel()
    private let bottomDivider = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.font = TMETheme.Fonts.body(12)
        badge.textColor = .secondaryLabel

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.backgroundColor = .secondarySystemGroupedBackground
        bubble.layer.cornerRadius = 16
        if #available(iOS 13.0, *) { bubble.layer.cornerCurve = .continuous }

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = TMETheme.Fonts.body(15)
        textLabel.textColor = .label
        textLabel.numberOfLines = 0

        bottomDivider.translatesAutoresizingMaskIntoConstraints = false
        bottomDivider.backgroundColor = UIColor.separator.withAlphaComponent(0.35)

        addSubview(badge)
        addSubview(bubble)
        bubble.addSubview(textLabel)
        addSubview(bottomDivider)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            bubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bubble.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bubble.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 6),

            textLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            textLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            textLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),

            bottomDivider.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomDivider.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomDivider.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 12),
            bottomDivider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
            bottomDivider.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureAsRootMessage(_ message: CommunityMessage) {
        badge.text = "Пост"
        textLabel.text = Self.displayText(for: message)
    }

    func configureAsParentComment(_ comment: CommunityComment) {
        badge.text = "Комментарий"
        textLabel.text = comment.text
    }

    private static func displayText(for message: CommunityMessage) -> String {
        switch message.kind {
        case .post:
            return message.text
        case .announcement:
            guard let a = message.announcement else { return message.text }
            let t = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? message.text : t
        }
    }
}

private final class CommentCell: UITableViewCell {
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
        /// На светлой теме `secondarySystemBackground` почти сливается с `systemGroupedBackground` экрана.
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
