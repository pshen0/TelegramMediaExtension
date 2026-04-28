import UIKit

final class CommunityCommentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {

    private let interactor: CommunityCommentsInteractor
    private enum InputBarMetrics {
        static let sideDiameter: CGFloat = 32
        static let barVerticalMargin: CGFloat = 6
        static let pillInnerVerticalPadding: CGFloat = 5
        static let minTextHeight: CGFloat = 20
        static var compactPillHeight: CGFloat { minTextHeight + pillInnerVerticalPadding * 2 }
        static let multilinePillMaxCornerRadius: CGFloat = 20
        static let gapLastCommentToInputBar: CGFloat = 10
        static let scrollPinnedBottomSlack: CGFloat = 48
        static let tableTopExtraPadding: CGFloat = 8
    }

    private var allowsOpeningNestedThread: Bool { interactor.threadParentCommentId == nil }

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
        let presenter = CommunityCommentsPresenter()
        let interactor = CommunityCommentsInteractor(
            presenter: presenter,
            rootMessage: message,
            threadParentCommentId: threadParentCommentId
        )
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
        presenter.view = self
        interactor.router = self
    }

    init(interactor: CommunityCommentsInteractor) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never
        title = interactor.threadParentCommentId == nil ? "Комментарии" : "Обсуждение"

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

        inputContainer.backgroundColor = .clear
        inputContainer.isOpaque = false
        inputContainer.isUserInteractionEnabled = true
        inputContainer.pinLeft(to: view)
        inputContainer.pinRight(to: view)
        inputContainer.pinBottom(to: view.keyboardLayoutGuide.topAnchor)

        let content = inputContainer

        sendButton.accessibilityLabel = "Отправить"
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        inputPill.clipsToBounds = true
        if #available(iOS 13.0, *) {
            inputPill.layer.cornerCurve = .continuous
        }
        inputPill.isOpaque = true
        inputPill.layer.borderWidth = 1.0 / UIScreen.main.scale

        inputField.font = TMETheme.Fonts.body(16)
        inputField.backgroundColor = .clear
        inputField.textColor = .label
        inputField.textContainerInset = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
        inputField.textContainer.lineFragmentPadding = 0
        inputField.isScrollEnabled = false
        inputField.delegate = self

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
        inputPillHeightConstraint = inputPill.setHeight(InputBarMetrics.compactPillHeight)
        textViewHeightConstraint = inputField.setHeight(InputBarMetrics.minTextHeight)

        inputPill.pinLeft(to: content.leadingAnchor, 10)
        inputPill.pinRight(to: sendButton.leadingAnchor, gap)
        inputPill.pinTop(to: content.topAnchor, InputBarMetrics.barVerticalMargin)
        content.pinBottom(to: inputPill, -InputBarMetrics.barVerticalMargin)

        sendButton.pinRight(to: content.trailingAnchor, 10)
        sendButton.pinCenterY(to: inputPill)
        sendButton.setWidth(side)
        sendButton.setHeight(side)

        inputField.pinLeft(to: inputPill.leadingAnchor, 10)
        inputField.pinTop(to: inputPill.topAnchor, InputBarMetrics.pillInnerVerticalPadding)
        inputField.pinRight(to: inputPill.trailingAnchor, 10)
        inputPlaceholderLabel.pinLeft(to: inputField.leadingAnchor, 8)
        inputPlaceholderLabel.pinCenterY(to: inputField)

        applyMediaLibraryChromeToInputBar()
        mediaLibraryChromeObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyMediaLibraryChromeToInputBar()
            self?.applyCommentsNavigationAppearance()
        }

        interactor.viewDidLoad(CommunityCommentsModel.ViewDidLoad.Request())
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
        interactor.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreCommentsNavigationAppearance()
        interactor.viewWillDisappear()
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

    private func updateContextHeader() {
        if interactor.threadParentCommentId == nil {
            contextHeader.configureAsRootMessage(interactor.rootMessage)
            return
        }
        if let parent = interactor.parentCommentForThreadHeader() {
            contextHeader.configureAsParentComment(parent)
        } else {
            contextHeader.configureAsParentComment(
                CommunityComment(messageId: interactor.rootMessage.id, threadParentCommentId: nil, text: "Комментарий")
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
        interactor.sendComment(CommunityCommentsModel.SendComment.Request(text: text))
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
        routeToNestedThread(commentId: c.id)
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

// MARK: - CommunityCommentsDisplayLogic

extension CommunityCommentsViewController: CommunityCommentsDisplayLogic {

    func displayComments(_ viewModel: CommunityCommentsModel.CommentsList.ViewModel) {
        comments = viewModel.comments
        tableView.reloadData()
        scrollToBottom(animated: viewModel.scrollAnimated)
        updateContextHeader()
        updateContextHeaderLayoutIfNeeded()
    }
}

// MARK: - CommunityCommentsRoutingLogic

extension CommunityCommentsViewController: CommunityCommentsRoutingLogic {

    func routeToNestedThread(commentId: UUID) {
        let next = CommunityCommentsBuilder.build(message: interactor.rootMessage, threadParentCommentId: commentId)
        navigationController?.pushViewController(next, animated: true)
    }
}
