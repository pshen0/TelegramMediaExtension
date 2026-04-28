import PhotosUI
import SafariServices
import UIKit

final class CommunityChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate {

    private let interactor: CommunityChatInteractor

    private let tableView = UITableView(frame: .zero, style: .plain)

    private let inputContainer = UIView()

    private let inputPill = UIView()
    private let inputField = UITextView()
    private let inputPlaceholderLabel = UILabel()
    private let announcementButton = UIButton(type: .system)
    private let spoilerTagButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var inputPillHeightConstraint: NSLayoutConstraint!
    private var textViewHeightConstraint: NSLayoutConstraint!

    private enum InputBarMetrics {
        static let sideDiameter: CGFloat = 32
        static let barVerticalMargin: CGFloat = 6
        static let pillInnerVerticalPadding: CGFloat = 5
        static let minTextHeight: CGFloat = 20
        static var compactPillHeight: CGFloat { minTextHeight + pillInnerVerticalPadding * 2 }

        static let multilinePillMaxCornerRadius: CGFloat = 20

        static let gapLastMessageToInputBar: CGFloat = 10

        static let scrollPinnedBottomSlack: CGFloat = 48

        static let tableTopExtraPadding: CGFloat = 8
    }

    private var messages: [CommunityMessage] = []
    private var pendingSpoilerTags: [CommunitySpoilerTag] = []
    private var revealedSpoilerMessageIds = Set<UUID>()
    private var canSendMessages = true
    private var mediaLibraryChromeObserver: NSObjectProtocol?
    private var keyboardFrameObserver: NSObjectProtocol?
    private var keyboardHideObserver: NSObjectProtocol?

    private var cachedKeyboardBottomOverlap: CGFloat = 0
    private lazy var dismissKeyboardTap: UITapGestureRecognizer = {
        let t = UITapGestureRecognizer(target: self, action: #selector(handleDismissKeyboardTap))
        t.cancelsTouchesInView = false
        t.delegate = self
        return t
    }()

    init(communityId: UUID) {
        let presenter = CommunityChatPresenter()
        let interactor = CommunityChatInteractor(presenter: presenter, communityId: communityId)
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
        presenter.view = self
        interactor.router = self
    }

    init(interactor: CommunityChatInteractor) {
        self.interactor = interactor
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.pencil"),
            style: .plain,
            target: self,
            action: #selector(editCommunityInfoTapped)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Изменить"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = .zero
        tableView.estimatedRowHeight = 140
        tableView.register(CommunityMessageCell.self, forCellReuseIdentifier: CommunityMessageCell.reuseId)

        view.addSubview(tableView)
        view.addSubview(inputContainer)
        view.addGestureRecognizer(dismissKeyboardTap)

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

        announcementButton.accessibilityLabel = "Новый анонс"
        announcementButton.addTarget(self, action: #selector(newAnnouncementTapped), for: .touchUpInside)

        spoilerTagButton.accessibilityLabel = "Привязать к произведению"
        spoilerTagButton.addTarget(self, action: #selector(spoilerTagTapped), for: .touchUpInside)
        refreshSpoilerTagButton()

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

        inputPlaceholderLabel.text = "Сообщение"
        inputPlaceholderLabel.font = inputField.font
        inputPlaceholderLabel.textColor = .placeholderText
        inputPlaceholderLabel.isUserInteractionEnabled = false

        content.addSubview(announcementButton)
        content.addSubview(spoilerTagButton)
        content.addSubview(inputPill)
        content.addSubview(sendButton)
        inputPill.addSubview(inputPlaceholderLabel)
        inputPill.addSubview(inputField)

        let side = InputBarMetrics.sideDiameter
        let gap: CGFloat = 8
        inputPillHeightConstraint = inputPill.setHeight(InputBarMetrics.compactPillHeight)
        textViewHeightConstraint = inputField.setHeight(InputBarMetrics.minTextHeight)

        announcementButton.pinLeft(to: content.leadingAnchor, 10)
        announcementButton.pinCenterY(to: inputPill)
        announcementButton.setWidth(side)
        announcementButton.setHeight(side)

        spoilerTagButton.pinLeft(to: announcementButton.trailingAnchor, 6)
        spoilerTagButton.pinCenterY(to: inputPill)
        spoilerTagButton.setWidth(side)
        spoilerTagButton.setHeight(side)

        sendButton.pinRight(to: content.trailingAnchor, 10)
        sendButton.pinCenterY(to: inputPill)
        sendButton.setWidth(side)
        sendButton.setHeight(side)

        inputPill.pinLeft(to: spoilerTagButton.trailingAnchor, gap)
        inputPill.pinRight(to: sendButton.leadingAnchor, gap)
        inputPill.pinTop(to: content.topAnchor, InputBarMetrics.barVerticalMargin)
        content.pinBottom(to: inputPill, -InputBarMetrics.barVerticalMargin)

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
            self?.applyChatNavigationAppearance()
            self?.tableView.reloadData()
        }

        interactor.viewDidLoad(CommunityChatModel.ViewDidLoad.Request())

        view.layoutIfNeeded()
        textViewDidChange(inputField)
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)

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
            self.animateWithKeyboardNotification(note) {
                self.updateChatTableBottomInset(keyboardOverlap: overlap, adjustScroll: true, deferGrowingScroll: true)
            } completion: {
                guard overlap > 0.5 else { return }
                self.scrollChatToLastRowRespectingInset(animated: false)
            }
        }

        keyboardHideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.cachedKeyboardBottomOverlap = 0
            self.updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: true, deferGrowingScroll: false)
        }
    }

    private func applyInputAvailability() {
        if !canSendMessages, inputField.isFirstResponder {
            inputField.resignFirstResponder()
        }
        inputContainer.isHidden = !canSendMessages
        navigationItem.rightBarButtonItem?.isEnabled = canSendMessages
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: true)
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

    private func updateChatTableBottomInset(keyboardOverlap: CGFloat? = nil, adjustScroll: Bool, deferGrowingScroll: Bool = false) {
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
        let gap = InputBarMetrics.gapLastMessageToInputBar
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
                scrollChatToLastRowRespectingInset(animated: false)
                DispatchQueue.main.async { [weak self] in
                    self?.scrollChatToLastRowRespectingInset(animated: false)
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

    private func scrollChatToLastRowRespectingInset(animated: Bool) {
        guard !messages.isEmpty else { return }
        let ip = IndexPath(row: messages.count - 1, section: 0)
        tableView.layoutIfNeeded()
        guard tableView.numberOfRows(inSection: 0) > ip.row else { return }
        tableView.scrollToRow(at: ip, at: .bottom, animated: animated)
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.messages.isEmpty else { return }
            let ip = IndexPath(row: self.messages.count - 1, section: 0)
            self.tableView.layoutIfNeeded()
            guard self.tableView.numberOfRows(inSection: 0) > ip.row else { return }
            self.tableView.scrollToRow(at: ip, at: .bottom, animated: false)
        }
    }

    @objc private func handleDismissKeyboardTap() {
        guard inputField.isFirstResponder else { return }
        inputField.resignFirstResponder()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === dismissKeyboardTap else { return true }
        var v: UIView? = touch.view
        while let cur = v {
            if cur === inputContainer || cur.isDescendant(of: inputContainer) { return false }
            if cur is UIButton { return false }
            v = cur.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateChatTableTopInset()
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        updateInputPillCornerRadius()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateChatTableTopInset()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyChatNavigationAppearance()
        interactor.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreChatNavigationAppearance()
        interactor.viewWillDisappear()
    }

    private func updateChatTableTopInset() {
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

    private func communityThreadNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        return appearance
    }

    private func applyChatNavigationAppearance() {
        let appearance = communityThreadNavigationBarAppearance()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }
        let accent = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        navigationController?.navigationBar.tintColor = accent
    }

    private func restoreChatNavigationAppearance() {
        navigationItem.standardAppearance = nil
        navigationItem.scrollEdgeAppearance = nil
        navigationItem.compactAppearance = nil
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = nil
        }
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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToInputBar()
        applyChatNavigationAppearance()
        for case let cell as CommunityMessageCell in tableView.visibleCells {
            cell.applyMediaLibraryChromeColors()
        }
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

        var tagCfg = UIButton.Configuration.plain()
        tagCfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        tagCfg.image = UIImage(systemName: pendingSpoilerTags.isEmpty ? "tag" : "tag.fill")

        tagCfg.baseForegroundColor = accent
        tagCfg.background.backgroundColor = .clear
        tagCfg.background.cornerRadius = r
        spoilerTagButton.configuration = tagCfg

        var annCfg = UIButton.Configuration.plain()
        annCfg.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        annCfg.image = UIImage(systemName: "sparkles")
        annCfg.baseForegroundColor = accent
        annCfg.background.backgroundColor = .clear
        announcementButton.configuration = annCfg

        inputPill.backgroundColor = .secondarySystemGroupedBackground
        inputPill.layer.borderColor = UIColor.separator.cgColor
    }

    private func scrollToBottom(animated: Bool) {
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        scrollChatToLastRowRespectingInset(animated: animated)
    }

    @objc private func editCommunityInfoTapped() {
        routeToEditCommunityProfile()
    }

    @objc private func sendTapped() {
        guard canSendMessages else { return }
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        interactor.sendMessage(CommunityChatModel.SendMessage.Request(text: text, spoilerTags: pendingSpoilerTags))
        inputField.text = ""
        pendingSpoilerTags = []
        refreshSpoilerTagButton()
        textViewDidChange(inputField)
    }

    @objc private func newAnnouncementTapped() {
        routeToNewAnnouncement()
    }

    @objc private func spoilerTagTapped() {
        presentSpoilerTagPicker()
    }

    private func presentSpoilerTagPicker() {
        guard pendingSpoilerTags.count < 5 else {
            let ac = UIAlertController(title: "Спойлер-теги", message: "Можно добавить максимум 5 тегов.", preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "Ок", style: .default))
            present(ac, animated: true)
            return
        }

        let picker = MediaCatalogSearchBuilder.build(style: .insetGrouped)
        picker.title = "Выберите произведение"
        picker.onSelectCandidate = { [weak self, weak picker] cand in
            guard let self else { return }
            guard cand.id.hasPrefix("tmdb-") else { return }
            picker?.dismiss(animated: true) {
                self.presentSpoilerTagValuePrompt(for: cand)
            }
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func presentSpoilerTagValuePrompt(for cand: MediaCatalogCandidate) {
        let title = "Спойлер-тег"
        switch cand.kind {
        case .series:
            let ac = UIAlertController(title: title, message: "\(cand.title)\nСезон и эпизод", preferredStyle: .alert)
            ac.addTextField { tf in
                tf.placeholder = "Сезон (например 1)"
                tf.keyboardType = .numberPad
                tf.text = "1"
            }
            ac.addTextField { tf in
                tf.placeholder = "Эпизод (например 3)"
                tf.keyboardType = .numberPad
                tf.text = "1"
            }
            ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            ac.addAction(UIAlertAction(title: "Готово", style: .default) { [weak self] _ in
                guard let self else { return }
                let s = Int(ac.textFields?[0].text ?? "") ?? 1
                let e = Int(ac.textFields?[1].text ?? "") ?? 1
                let hashtag = self.makeSpoilerHashtag(title: cand.title, suffix: "s\(s)e\(e)")
                let tag = CommunitySpoilerTag(
                    catalogSourceID: cand.id,
                    mediaTitle: cand.title,
                    kind: .seriesEpisode,
                    season: s,
                    episode: e,
                    timeMinutes: nil,
                    hashtag: hashtag
                )
                self.appendSpoilerTagToInputAndState(tag)
                self.refreshSpoilerTagButton()
            })
            present(ac, animated: true)
        case .film:
            let ac = UIAlertController(title: title, message: "\(cand.title)\nТаймкод (HH:MM)", preferredStyle: .alert)
            ac.addTextField { tf in
                tf.placeholder = "Например 00:45"
                tf.keyboardType = .numbersAndPunctuation
            }
            ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            ac.addAction(UIAlertAction(title: "Готово", style: .default) { [weak self] _ in
                guard let self else { return }
                let raw = (ac.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let mins = self.parseTimecodeMinutes(raw) ?? 0
                let tc = self.formatTimecode(minutes: mins)
                let hashtag = self.makeSpoilerHashtag(title: cand.title, suffix: tc.replacingOccurrences(of: ":", with: "_"))
                let tag = CommunitySpoilerTag(
                    catalogSourceID: cand.id,
                    mediaTitle: cand.title,
                    kind: .filmTimecode,
                    season: nil,
                    episode: nil,
                    timeMinutes: mins,
                    hashtag: hashtag
                )
                self.appendSpoilerTagToInputAndState(tag)
                self.refreshSpoilerTagButton()
            })
            present(ac, animated: true)
        default:
            return
        }
    }

    private func makeSpoilerHashtag(title: String, suffix: String) -> String {
        let norm = MediaHashtag.normalize(title) ?? "spoiler"
        let cleanSuffix = suffix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "#\(norm)_\(cleanSuffix)"
    }

    private func parseTimecodeMinutes(_ raw: String) -> Int? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let parts = t.split(separator: ":").map(String.init)
        if parts.count == 2 {
            let hh = Int(parts[0]) ?? 0
            let mm = Int(parts[1]) ?? 0
            return max(0, hh) * 60 + max(0, mm)
        }
        if let mm = Int(t) { return max(0, mm) }
        return nil
    }

    private func formatTimecode(minutes: Int) -> String {
        let m = max(0, minutes)
        let hh = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", hh, mm)
    }

    private func refreshSpoilerTagButton() {
        let imgName = pendingSpoilerTags.isEmpty ? "tag" : "tag.fill"
        spoilerTagButton.setImage(UIImage(systemName: imgName), for: .normal)
        spoilerTagButton.configuration?.image = UIImage(systemName: imgName)
        spoilerTagButton.accessibilityValue = pendingSpoilerTags.isEmpty ? nil : "\(pendingSpoilerTags.count)"

        applyMediaLibraryChromeToInputBar()
    }

    private func appendSpoilerTagToInputAndState(_ tag: CommunitySpoilerTag) {
        guard pendingSpoilerTags.count < 5 else { return }
        pendingSpoilerTags.append(tag)

        let existing = (inputField.text ?? "")
        if existing.contains(tag.hashtag) {
            textViewDidChange(inputField)
            return
        }
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.isEmpty ? tag.hashtag : (existing + "\n" + tag.hashtag)
        inputField.text = next
        textViewDidChange(inputField)
        inputField.becomeFirstResponder()
        let end = inputField.endOfDocument
        inputField.selectedTextRange = inputField.textRange(from: end, to: end)
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
        let saved = interactor.announcementIsSaved(for: msg)
        let spoiler = interactor.spoilerDecision(for: msg)
        let isRevealed = revealedSpoilerMessageIds.contains(msg.id)
        cell.configure(message: msg, announcementIsSaved: saved, spoiler: spoiler, spoilerIsRevealed: isRevealed)
        cell.onRevealSpoiler = { [weak self] messageId in
            guard let self else { return }
            self.revealedSpoilerMessageIds.insert(messageId)
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
        cell.onSaveAnnouncement = { [weak self] msg in
            self?.interactor.saveAnnouncementFromMessage(msg)
        }
        cell.onOpenComments = { [weak self] msg in
            guard let self else { return }
            self.routeToComments(message: msg)
        }
        cell.onOpenLink = { [weak self] url in
            guard let self else { return }
            self.presentSafari(url: url)
        }
        cell.onOpenLocation = { [weak self] loc in
            guard let self else { return }
            let url = YandexMapsURL.point(latitude: loc.latitude, longitude: loc.longitude)
            self.openExternalURL(url)
        }
        return cell
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard textView === inputField else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
            self.scrollChatToLastRowRespectingInset(animated: false)
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
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: true)
    }
}

// MARK: - CommunityChatDisplayLogic

extension CommunityChatViewController: CommunityChatDisplayLogic {

    func displayMessages(_ viewModel: CommunityChatModel.Messages.ViewModel) {
        messages = viewModel.messages
        tableView.reloadData()
        scrollToBottom(animated: viewModel.scrollAnimated)
    }

    func displayNavigationTitle(_ title: String) {
        self.title = title
    }

    func displayInputAvailability(_ viewModel: CommunityChatModel.InputAvailability.ViewModel) {
        canSendMessages = viewModel.canSendMessages
        applyInputAvailability()
    }

    func reloadCellsForDependentStores() {
        tableView.reloadData()
    }
}

// MARK: - CommunityChatRoutingLogic

extension CommunityChatViewController: CommunityChatRoutingLogic {

    func routeToEditCommunityProfile() {
        let ed = EditCommunityProfileViewController(communityId: interactor.communityId)
        let nav = UINavigationController(rootViewController: ed)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    func routeToNewAnnouncement() {
        let vc = NewAnnouncementBuilder.build(communityId: interactor.communityId)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    func routeToComments(message: CommunityMessage) {
        navigationController?.pushViewController(CommunityCommentsBuilder.build(message: message), animated: true)
    }

    func presentSafari(url: URL) {
        present(SFSafariViewController(url: url), animated: true)
    }

    func openExternalURL(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
