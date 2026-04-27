import Combine
import PhotosUI
import SafariServices
import UIKit

final class CommunityChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate {
    private let store = CommunityStore.shared
    private let mediaStore = MediaLibraryStore.shared
    private let communityId: UUID
    private var cancellables = Set<AnyCancellable>()

    private let tableView = UITableView(frame: .zero, style: .plain)
    /// Панель ввода без размытия (фон прозрачный, только непрозрачные контролы).
    private let inputContainer = UIView()
    /// Капсула вокруг поля ввода.
    private let inputPill = UIView()
    private let inputField = UITextView()
    private let inputPlaceholderLabel = UILabel()
    private let announcementButton = UIButton(type: .system)
    private let spoilerTagButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)
    private var inputPillHeightConstraint: NSLayoutConstraint!
    private var textViewHeightConstraint: NSLayoutConstraint!

    private enum InputBarMetrics {
        /// Диаметр круглых кнопок (анонс / отправка), совпадает с высотой однострочной капсулы.
        static let sideDiameter: CGFloat = 32
        static let barVerticalMargin: CGFloat = 6
        static let pillInnerVerticalPadding: CGFloat = 5
        static let minTextHeight: CGFloat = 20
        static var compactPillHeight: CGFloat { minTextHeight + pillInnerVerticalPadding * 2 }
        /// При 2+ строках не используем `h/2`, иначе поле выглядит как вытянутый цилиндр.
        static let multilinePillMaxCornerRadius: CGFloat = 20
        /// Как между двумя карточками в ленте: `CommunityMessageCell` spacingBelowCard + spacingAboveCard.
        static let gapLastMessageToInputBar: CGFloat = 10
        /// Зона «как у нижнего края» при открытой клавиатуре (избегаем ложного «не в конце» из‑за округления).
        static let scrollPinnedBottomSlack: CGFloat = 48
        /// Доп. отступ контента под размытый навбар (как был `contentInset.top` при привязке к safe area).
        static let tableTopExtraPadding: CGFloat = 8
    }

    private var messages: [CommunityMessage] = []
    private var pendingSpoilerTags: [CommunitySpoilerTag] = []
    private var revealedSpoilerMessageIds = Set<UUID>()
    private var mediaLibraryChromeObserver: NSObjectProtocol?
    private var keyboardFrameObserver: NSObjectProtocol?
    private var keyboardHideObserver: NSObjectProtocol?
    /// Последняя высота перекрытия клавиатуры из уведомления — при росте только поля ввода layout/guide может временно давать 0.
    private var cachedKeyboardBottomOverlap: CGFloat = 0
    private lazy var dismissKeyboardTap: UITapGestureRecognizer = {
        let t = UITapGestureRecognizer(target: self, action: #selector(handleDismissKeyboardTap))
        t.cancelsTouchesInView = false
        t.delegate = self
        return t
    }()

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

        announcementButton.translatesAutoresizingMaskIntoConstraints = false
        announcementButton.accessibilityLabel = "Новый анонс"
        announcementButton.addTarget(self, action: #selector(newAnnouncementTapped), for: .touchUpInside)

        spoilerTagButton.translatesAutoresizingMaskIntoConstraints = false
        spoilerTagButton.accessibilityLabel = "Привязать к произведению"
        spoilerTagButton.addTarget(self, action: #selector(spoilerTagTapped), for: .touchUpInside)
        refreshSpoilerTagButton()

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
        inputPillHeightConstraint = inputPill.heightAnchor.constraint(equalToConstant: InputBarMetrics.compactPillHeight)
        textViewHeightConstraint = inputField.heightAnchor.constraint(equalToConstant: InputBarMetrics.minTextHeight)

        NSLayoutConstraint.activate([
            announcementButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            announcementButton.centerYAnchor.constraint(equalTo: inputPill.centerYAnchor),
            announcementButton.widthAnchor.constraint(equalToConstant: side),
            announcementButton.heightAnchor.constraint(equalToConstant: side),

            spoilerTagButton.leadingAnchor.constraint(equalTo: announcementButton.trailingAnchor, constant: 6),
            spoilerTagButton.centerYAnchor.constraint(equalTo: inputPill.centerYAnchor),
            spoilerTagButton.widthAnchor.constraint(equalToConstant: side),
            spoilerTagButton.heightAnchor.constraint(equalToConstant: side),

            sendButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputPill.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: side),
            sendButton.heightAnchor.constraint(equalToConstant: side),

            inputPill.leadingAnchor.constraint(equalTo: spoilerTagButton.trailingAnchor, constant: gap),
            inputPill.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -gap),
            inputPill.topAnchor.constraint(equalTo: content.topAnchor, constant: InputBarMetrics.barVerticalMargin),
            inputPillHeightConstraint,
            content.bottomAnchor.constraint(equalTo: inputPill.bottomAnchor, constant: InputBarMetrics.barVerticalMargin),

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
            self?.applyChatNavigationAppearance()
            self?.tableView.reloadData()
        }

        bind()
        reloadMessagesAndScroll(animated: false)

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

    /// Высота пересечения клавиатуры с нижней частью `view` по `keyboardFrameEndUserInfoKey`.
    private func keyboardOverlapHeight(from note: Notification) -> CGFloat {
        guard let rect = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }
        var best = max(0, view.bounds.maxY - view.convert(rect, from: nil).minY)
        if let win = view.window {
            best = max(best, max(0, view.bounds.maxY - view.convert(rect, from: win).minY))
            best = max(best, max(0, view.bounds.maxY - view.convert(rect, from: win.screen.coordinateSpace).minY))
        }
        return best
    }

    /// Часть экрана под панелью ввода, занятая клавиатурой (без высоты самой панели), из текущего layout.
    private func keyboardOverlapFromInputBarLayout() -> CGFloat {
        max(0, view.bounds.maxY - inputContainer.frame.maxY)
    }

    /// Перекрытие клавиатурой по `keyboardLayoutGuide` (не обнуляется между кадрами анимации).
    private func keyboardOverlapFromKeyboardGuide() -> CGFloat {
        let lf = view.keyboardLayoutGuide.layoutFrame
        guard lf.height > 0.5 || lf.minY < view.bounds.maxY - 0.5 else { return 0 }
        return max(0, view.bounds.maxY - lf.minY)
    }

    /// Снизу таблицы: высота панели + пересечение с клавиатурой + отступ как между сообщениями.
    /// - Parameter deferGrowingScroll: при росте inset (клавиатура открывается) не трогать offset здесь — прокрутка после анимации.
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

    /// Прокрутка к последнему сообщению с учётом `contentInset` (над панелью и клавиатурой).
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreChatNavigationAppearance()
    }

    /// Как список «Сообщества»: контент уходит под навбар и виден через размытие, а не под сплошную подложку.
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
        // Заполняем сам тег (`tag.fill`), без «круга» вокруг.
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

    private func bind() {
        store.$communities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.title = self.store.communities.first(where: { $0.id == self.communityId })?.title ?? "Сообщество"
            }
            .store(in: &cancellables)

        store.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reloadMessagesAndScroll(animated: true)
            }
            .store(in: &cancellables)

        mediaStore.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Прогресс в медиатеке влияет на видимость спойлеров.
                self?.tableView.reloadData()
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
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        scrollChatToLastRowRespectingInset(animated: animated)
    }

    @objc private func editCommunityInfoTapped() {
        let ed = EditCommunityProfileViewController(communityId: communityId)
        let nav = UINavigationController(rootViewController: ed)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func sendTapped() {
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.addPost(communityId: communityId, text: text, spoilerTags: pendingSpoilerTags)
        inputField.text = ""
        pendingSpoilerTags = []
        refreshSpoilerTagButton()
        textViewDidChange(inputField)
    }

    @objc private func newAnnouncementTapped() {
        let vc = NewAnnouncementViewController(communityId: communityId)
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
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

        let picker = MediaCatalogSearchViewController(style: .insetGrouped)
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
        // Обновить заливку/цвет, если состояние изменилось вне traitCollectionDidChange.
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
        let saved = store.savedAnnouncements.contains(where: { $0.sourceMessageId == msg.id })
        let spoiler = spoilerDecision(for: msg)
        let isRevealed = revealedSpoilerMessageIds.contains(msg.id)
        cell.configure(message: msg, announcementIsSaved: saved, spoiler: spoiler, spoilerIsRevealed: isRevealed)
        cell.onRevealSpoiler = { [weak self] messageId in
            guard let self else { return }
            self.revealedSpoilerMessageIds.insert(messageId)
            self.tableView.reloadRows(at: [indexPath], with: .fade)
        }
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

    fileprivate struct SpoilerDecision {
        let title: String
        let subtitle: String
        let messageId: UUID
    }

    private func spoilerDecision(for message: CommunityMessage) -> SpoilerDecision? {
        guard message.kind == .post else { return nil }
        guard !message.spoilerTags.isEmpty else { return nil }

        for tag in message.spoilerTags {
            guard tag.catalogSourceID.hasPrefix("tmdb-") else { continue }
            guard let item = mediaStore.item(catalogSourceID: tag.catalogSourceID) else { continue }
            guard item.spoilersProtectionEnabled else { continue }

            if tagIsAheadOfProgress(tag: tag, item: item) {
                return SpoilerDecision(
                    title: tag.mediaTitle,
                    subtitle: spoilerSubtitle(for: tag),
                    messageId: message.id
                )
            }
        }
        return nil
    }

    private func tagIsAheadOfProgress(tag: CommunitySpoilerTag, item: MediaItem) -> Bool {
        switch (tag.kind, item.kind) {
        case (.filmTimecode, .film):
            let current = max(0, item.progress.current ?? 0)
            let tm = max(0, tag.timeMinutes ?? 0)
            return tm > current
        case (.seriesEpisode, .series):
            let curSeason = max(1, item.progress.season ?? 1)
            let curEpisode = max(0, item.progress.current ?? 0)
            let s = max(1, tag.season ?? 1)
            let e = max(0, tag.episode ?? 0)
            if s > curSeason { return true }
            if s < curSeason { return false }
            return e > curEpisode
        default:
            return false
        }
    }

    private func spoilerSubtitle(for tag: CommunitySpoilerTag) -> String {
        switch tag.kind {
        case .seriesEpisode:
            let s = max(1, tag.season ?? 1)
            let e = max(1, tag.episode ?? 1)
            return "Сезон \(s), эпизод \(e)"
        case .filmTimecode:
            let m = max(0, tag.timeMinutes ?? 0)
            let hh = m / 60
            let mm = m % 60
            return String(format: "Таймкод %02d:%02d", hh, mm)
        }
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

// MARK: - Редактирование названия и аватара (только из чата)

private final class EditCommunityProfileViewController: UITableViewController, PHPickerViewControllerDelegate {
    private enum Section: Int {
        case avatar = 0
        case name = 1
    }

    private let communityId: UUID
    private let store = CommunityStore.shared
    private var pendingAvatarJPEG: Data?
    private var showsAvatarPlaceholder = false
    private var bannerColorObserver: NSObjectProtocol?
    private var editedTitle = ""
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()
    private var doneButtonView: LiquidGlassBarButtonView?

    init(communityId: UUID) {
        self.communityId = communityId
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.titleView = nil
        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancelTapped))
        let doneView = LiquidGlassBarButtonView(
            symbolName: "checkmark",
            accessibilityLabel: "Сохранить",
            symbolPointSize: 17,
            showsBackground: false,
            action: { [weak self] in self?.saveTapped() }
        )
        doneView.updateBlurStyle(for: traitCollection)
        doneButtonView = doneView
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: doneView)

        tableView.register(CommunityAvatarEditCell.self, forCellReuseIdentifier: CommunityAvatarEditCell.reuseId)

        reloadFromStore()

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.showsAvatarPlaceholder else { return }
            self.tableView.reloadSections(IndexSet(integer: Section.avatar.rawValue), with: .none)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        doneButtonView?.updateBlurStyle(for: traitCollection)
        if showsAvatarPlaceholder {
            tableView.reloadSections(IndexSet(integer: Section.avatar.rawValue), with: .none)
        }
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    private func makeNavTitleView(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = TMETheme.Fonts.titleSemibold(17)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.72
        label.lineBreakMode = .byClipping
        label.textAlignment = .center
        return label
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Кнопки в навбаре — системного tint.
    }

    private func applyAvatarPlaceholderChrome(to avatarView: UIImageView) {
        avatarView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        avatarView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    private func reloadFromStore() {
        guard let chat = store.communities.first(where: { $0.id == communityId }) else { return }
        editedTitle = chat.title
        pendingAvatarJPEG = nil
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let s = Section(rawValue: section) else { return nil }
        switch s {
        case .avatar: return nil
        case .name: return "Название"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .avatar:
            let cell = tableView.dequeueReusableCell(withIdentifier: CommunityAvatarEditCell.reuseId, for: indexPath) as! CommunityAvatarEditCell
            cell.backgroundConfiguration = UIBackgroundConfiguration.clear()
            cell.onPhotoAction = { [weak self] in self?.changePhotoTapped() }
            configureAvatar(cell)
            return cell
        case .name:
            let cell = CommunityTextFieldCell(
                title: "Сообщество",
                value: editedTitle,
                placeholder: "Название сообщества",
                keyboard: .default
            ) { [weak self] t in
                self?.editedTitle = t
            }
            cell.field.autocapitalizationType = .sentences
            cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = Section(rawValue: indexPath.section) else { return 52 }
        switch section {
        case .avatar: return 180
        case .name: return 52
        }
    }

    private func configureAvatar(_ cell: CommunityAvatarEditCell) {
        let avatarView = cell.avatarView
        if let d = pendingAvatarJPEG, let img = UIImage(data: d) {
            showsAvatarPlaceholder = false
            avatarView.contentMode = .scaleAspectFill
            avatarView.image = img
            avatarView.tintColor = nil
            avatarView.backgroundColor = .clear
            return
        }
        guard let chat = store.communities.first(where: { $0.id == communityId }) else { return }
        if let name = chat.avatarFileName,
           let url = CommunityStore.communityAvatarURL(fileName: name),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            showsAvatarPlaceholder = false
            avatarView.contentMode = .scaleAspectFill
            avatarView.image = img
            avatarView.tintColor = nil
            avatarView.backgroundColor = .clear
        } else {
            showsAvatarPlaceholder = true
            avatarView.contentMode = .center
            let cfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
            avatarView.image = UIImage(systemName: "person.2.fill", withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate)
            applyAvatarPlaceholderChrome(to: avatarView)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let a = UIAlertController(title: "Введите название", message: nil, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Ок", style: .default))
            present(a, animated: true)
            return
        }
        store.setCommunityTitle(communityId: communityId, title: trimmed)
        if let d = pendingAvatarJPEG {
            try? store.setCommunityAvatar(communityId: communityId, jpegData: d)
        }
        dismiss(animated: true)
    }

    @objc private func changePhotoTapped() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let pr = results.first else { return }
        pr.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            DispatchQueue.main.async {
                guard let self, let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.88) else { return }
                self.pendingAvatarJPEG = data
                self.showsAvatarPlaceholder = false
                self.tableView.reloadSections(IndexSet(integer: Section.avatar.rawValue), with: .none)
            }
        }
    }
}

private final class CommunityMessageCell: UITableViewCell {
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
    private var spoilerDecision: CommunityChatViewController.SpoilerDecision?
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
        spoiler: CommunityChatViewController.SpoilerDecision?,
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

// MARK: - Spoiler overlay (blur + "помехи")

private final class SpoilerOverlayView: UIControl {
    var onTap: (() -> Void)?

    var title: String = "" { didSet { titleLabel.text = title; updateAccessibility() } }
    var subtitle: String = "" { didSet { subtitleLabel.text = subtitle; updateAccessibility() } }

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dim = UIView()
    private let particles = SpoilerParticlesView()

    private let pill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        clipsToBounds = true
        layer.cornerRadius = 16
        if #available(iOS 13.0, *) { layer.cornerCurve = .continuous }

        addTarget(self, action: #selector(tapped), for: .touchUpInside)

        blur.isUserInteractionEnabled = false
        dim.isUserInteractionEnabled = false
        particles.isUserInteractionEnabled = false
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.20)

        pill.isUserInteractionEnabled = false
        pill.clipsToBounds = true
        pill.layer.cornerRadius = 12
        if #available(iOS 13.0, *) { pill.layer.cornerCurve = .continuous }

        // Название и сезон/эпизод — одинаковый шрифт.
        titleLabel.font = TMETheme.Fonts.body(13)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center

        subtitleLabel.font = TMETheme.Fonts.body(13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.textAlignment = .center

        addSubview(blur)
        addSubview(dim)
        addSubview(particles)
        addSubview(pill)

        pill.contentView.addSubview(titleLabel)
        pill.contentView.addSubview(subtitleLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        onTap?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            particles.stop()
        } else if !isHidden {
            particles.start()
        }
    }

    override var isHidden: Bool {
        didSet {
            if isHidden {
                particles.stop()
            } else if window != nil {
                particles.start()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blur.frame = bounds
        dim.frame = bounds
        particles.frame = bounds

        // Компактная плашка по центру.
        let maxW = min(bounds.width - 16, 220)

        let pad: CGFloat = 6
        let interLine: CGFloat = 3
        let maxInnerW = max(60, maxW - pad * 2)

        // Делаем ширину плашки по фактической ширине текста, а не фиксированной,
        // иначе визуально горизонтальные отступы выглядят больше вертикальных.
        let titleSize = titleLabel.sizeThatFits(CGSize(width: maxInnerW, height: 200))
        let subSize = subtitleLabel.sizeThatFits(CGSize(width: maxInnerW, height: 200))
        let usedInnerW = min(maxInnerW, max(ceil(titleSize.width), ceil(subSize.width)))
        let contentW = max(120, min(maxW, usedInnerW + pad * 2))
        let innerW = contentW - pad * 2

        let titleH = ceil(titleLabel.sizeThatFits(CGSize(width: innerW, height: 200)).height)
        let subH = ceil(subtitleLabel.sizeThatFits(CGSize(width: innerW, height: 200)).height)
        let totalH = pad + titleH + interLine + subH + pad

        pill.bounds = CGRect(x: 0, y: 0, width: contentW, height: totalH)
        pill.center = CGPoint(x: bounds.midX, y: bounds.midY)

        var y: CGFloat = pad
        titleLabel.frame = CGRect(x: pad, y: y, width: innerW, height: titleH)
        y = titleLabel.frame.maxY + interLine
        subtitleLabel.frame = CGRect(x: pad, y: y, width: innerW, height: subH)
    }

    private func updateAccessibility() {
        let t = title.isEmpty ? "Спойлер" : title
        let s = subtitle.isEmpty ? "" : ", \(subtitle)"
        accessibilityLabel = "Спойлер: \(t)\(s)"
        accessibilityHint = "Нажмите, чтобы показать"
    }
}

/// Белые точки, «летающие» по оверлею (похоже на Telegram spoiler).
private final class SpoilerParticlesView: UIView {
    private let emitter = CAEmitterLayer()
    private var running = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(emitter)

        emitter.emitterShape = .rectangle
        emitter.renderMode = .additive
        emitter.seed = arc4random()
        emitter.opacity = 0.85
        emitter.birthRate = 0

        let cell = CAEmitterCell()
        cell.contents = Self.dotImage()?.cgImage
        cell.birthRate = 130
        cell.lifetime = 6.2
        cell.lifetimeRange = 1.2
        cell.velocity = 16
        cell.velocityRange = 12
        cell.emissionRange = .pi * 2
        cell.scale = 0.045
        cell.scaleRange = 0.025
        cell.alphaSpeed = -0.06
        cell.spin = 0.6
        cell.spinRange = 1.2
        cell.color = UIColor(white: 1, alpha: 0.9).cgColor

        emitter.emitterCells = [cell]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = CGSize(width: bounds.width, height: bounds.height)
    }

    func start() {
        guard !running else { return }
        running = true
        emitter.birthRate = 1
    }

    func stop() {
        guard running else { return }
        running = false
        emitter.birthRate = 0
    }

    private static func dotImage() -> UIImage? {
        let side: CGFloat = 10
        let r = side / 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.addEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            ctx.cgContext.fillPath()
            // мягкое свечение
            ctx.cgContext.setShadow(offset: .zero, blur: 3, color: UIColor.white.withAlphaComponent(0.6).cgColor)
            ctx.cgContext.addEllipse(in: CGRect(x: r - 1, y: r - 1, width: 2, height: 2))
            ctx.cgContext.fillPath()
        }
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
