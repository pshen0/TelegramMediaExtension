import Combine
import PhotosUI
import SafariServices
import UIKit

final class CommunityChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, UIGestureRecognizerDelegate {
    private let store = CommunityStore.shared
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
        /// Как между двумя карточками в ленте: `CommunityMessageCell` spacingBelowCard + spacingAboveCard.
        static let gapLastMessageToInputBar: CGFloat = 20
    }

    private var messages: [CommunityMessage] = []
    private var mediaLibraryChromeObserver: NSObjectProtocol?
    private var keyboardFrameObserver: NSObjectProtocol?
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
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        tableView.estimatedRowHeight = 140
        tableView.register(CommunityMessageCell.self, forCellReuseIdentifier: CommunityMessageCell.reuseId)

        view.addSubview(tableView)
        view.addSubview(inputContainer)
        view.addGestureRecognizer(dismissKeyboardTap)

        tableView.pinTop(to: view.safeAreaLayoutGuide.topAnchor)
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

            sendButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: inputPill.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: side),
            sendButton.heightAnchor.constraint(equalToConstant: side),

            inputPill.leadingAnchor.constraint(equalTo: announcementButton.trailingAnchor, constant: gap),
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
            self.animateWithKeyboardNotification(note) {
                self.updateChatTableBottomInset(keyboardOverlap: overlap, adjustScroll: true, deferGrowingScroll: true)
            } completion: {
                guard overlap > 0.5 else { return }
                self.scrollChatToLastRowRespectingInset(animated: false)
            }
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
        let mergedLocal = max(fromLayout, fromGuide)
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

        var inset = tableView.contentInset
        inset.bottom = newBottom
        tableView.contentInset = inset
        var ind = tableView.verticalScrollIndicatorInsets
        ind.bottom = inset.bottom
        tableView.verticalScrollIndicatorInsets = ind

        guard adjustScroll, abs(delta) > 0.5 else { return }

        let newMaxY = max(0, tableView.contentSize.height - tableView.bounds.height + newBottom)

        if delta > 0 {
            if !deferGrowingScroll {
                scrollChatToLastRowRespectingInset(animated: false)
            }
            return
        }

        let oldMaxY = max(0, tableView.contentSize.height - tableView.bounds.height + oldBottom)
        let wasAtBottom = tableView.contentOffset.y >= oldMaxY - 4

        if wasAtBottom {
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
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
        let h = inputPill.bounds.height
        guard h > 1 else { return }
        inputPill.layer.cornerRadius = h * 0.5
    }

    deinit {
        if let mediaLibraryChromeObserver {
            NotificationCenter.default.removeObserver(mediaLibraryChromeObserver)
        }
        if let keyboardFrameObserver {
            NotificationCenter.default.removeObserver(keyboardFrameObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyMediaLibraryChromeToInputBar()
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
            let h = self.inputPill.bounds.height
            if h > 1 {
                self.inputPill.layer.cornerRadius = h * 0.5
            }
        }
        updateChatTableBottomInset(keyboardOverlap: nil, adjustScroll: false)
    }
}

// MARK: - Редактирование названия и аватара (только из чата)

private final class EditCommunityProfileViewController: UIViewController, UITextFieldDelegate, PHPickerViewControllerDelegate {
    private let communityId: UUID
    private let store = CommunityStore.shared
    private var pendingAvatarJPEG: Data?
    private var showsAvatarPlaceholder = false
    private var bannerColorObserver: NSObjectProtocol?

    private let avatarView = UIImageView()
    private let nameField = UITextField()
    private let changePhotoButton = UIButton(type: .system)

    init(communityId: UUID) {
        self.communityId = communityId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Изменить"

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Отмена", style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(saveTapped))

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.layer.cornerRadius = 50
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changePhotoTapped)))

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.borderStyle = .roundedRect
        nameField.font = TMETheme.Fonts.body(17)
        nameField.placeholder = "Название сообщества"
        nameField.autocapitalizationType = .sentences
        nameField.returnKeyType = .done
        nameField.delegate = self

        changePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        changePhotoButton.setTitle("Сменить фото", for: .normal)
        changePhotoButton.titleLabel?.font = TMETheme.Fonts.body(15)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)

        view.addSubview(avatarView)
        view.addSubview(changePhotoButton)
        view.addSubview(nameField)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            avatarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 100),
            avatarView.heightAnchor.constraint(equalToConstant: 100),

            changePhotoButton.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 12),
            changePhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            nameField.topAnchor.constraint(equalTo: changePhotoButton.bottomAnchor, constant: 28),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nameField.heightAnchor.constraint(equalToConstant: 44)
        ])

        reloadFromStore()
        applyEditChromeColors()

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.showsAvatarPlaceholder else { return }
            self.applyAvatarPlaceholderChrome()
        }
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyEditChromeColors()
        if showsAvatarPlaceholder {
            applyAvatarPlaceholderChrome()
        }
    }

    private func applyEditChromeColors() {
        let c = MediaLibraryHeaderBannerColor.catalogChromeAccent(for: traitCollection)
        changePhotoButton.setTitleColor(c, for: .normal)
        navigationItem.rightBarButtonItem?.tintColor = c
    }

    private func applyAvatarPlaceholderChrome() {
        avatarView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        avatarView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    private func reloadFromStore() {
        guard let chat = store.communities.first(where: { $0.id == communityId }) else { return }
        nameField.text = chat.title
        pendingAvatarJPEG = nil
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
            applyAvatarPlaceholderChrome()
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let t = nameField.text ?? ""
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
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

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let pr = results.first else { return }
        pr.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            DispatchQueue.main.async {
                guard let self, let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.88) else { return }
                self.pendingAvatarJPEG = data
                self.showsAvatarPlaceholder = false
                self.avatarView.contentMode = .scaleAspectFill
                self.avatarView.backgroundColor = .clear
                self.avatarView.image = img
                self.avatarView.tintColor = nil
            }
        }
    }
}

private final class CommunityMessageCell: UITableViewCell {
    static let reuseId = "CommunityMessageCell"

    /// Вертикальные отступы между карточками в ленте (одинаково для поста и анонса).
    private enum LayoutMetrics {
        static let spacingAboveCard: CGFloat = 10
        static let spacingBelowCard: CGFloat = 10
        static let horizontalInset: CGFloat = 16
        static let announcementInnerTop: CGFloat = 10
        static let announcementImageHeight: CGFloat = 180
        static let announcementImageBottomGap: CGFloat = 10
        static let titleBodyGap: CGFloat = 8
        static let bodyBottomGap: CGFloat = 10
        static let linkBottomGap: CGFloat = 6
        static let footerRowHeight: CGFloat = 22
        static let footerBottomPadding: CGFloat = 10
    }

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

    static func height(for message: CommunityMessage, tableWidth: CGFloat) -> CGFloat {
        let w = max(0, tableWidth)
        let side = LayoutMetrics.horizontalInset
        let maxCardW = w - side * 2
        if message.kind == .post {
            let text = message.text
            let padX: CGFloat = 12
            let padTop: CGFloat = 10
            let padBottom: CGFloat = 10
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let timeTrailingInset: CGFloat = 14
            let gapTextTime: CGFloat = 6
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

        var y: CGFloat = LayoutMetrics.announcementInnerTop
        let bw = maxCardW
        let a = message.announcement
        let imgExists: Bool = {
            guard let name = a?.imageFileName, let u = CommunityStore.announcementImageURL(fileName: name) else { return false }
            return FileManager.default.fileExists(atPath: u.path)
        }()
        if imgExists {
            y += LayoutMetrics.announcementImageHeight + LayoutMetrics.announcementImageBottomGap
        }

        let title = "Анонс" + (a?.title.isEmpty == false ? ": \(a!.title)" : "")
        let titleH = ceil((title as NSString).boundingRect(
            with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.titleSemibold(15)],
            context: nil
        ).height)
        y += titleH + LayoutMetrics.titleBodyGap

        let bodyText = (a?.details?.isEmpty == false ? a!.details : message.text) ?? ""
        let bh = ceil((bodyText as NSString).boundingRect(
            with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: TMETheme.Fonts.body(15)],
            context: nil
        ).height)
        y += max(1, bh) + LayoutMetrics.bodyBottomGap

        if let link = a?.linkURL?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
            let t = "Ссылка: \(link)"
            y += ceil((t as NSString).boundingRect(
                with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: TMETheme.Fonts.body(13)],
                context: nil
            ).height) + LayoutMetrics.linkBottomGap
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

            let padX: CGFloat = 12
            let padTop: CGFloat = 10
            let padBottom: CGFloat = 10
            let timeWMax: CGFloat = 56
            let timeH: CGFloat = 16
            let timeTrailingInset: CGFloat = 14
            let gapTextTime: CGFloat = 6
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
        } else {
            bubble.isHidden = false
            postBubble.isHidden = true

            var y: CGFloat = LayoutMetrics.announcementInnerTop
            let x: CGFloat = side
            let bw = maxCardW

            let hasImage = !announcementImageView.isHidden && announcementImageView.image != nil
            if hasImage {
                let ih = LayoutMetrics.announcementImageHeight
                announcementImageView.frame = CGRect(x: 10, y: y, width: bw - 20, height: ih)
                y = announcementImageView.frame.maxY + LayoutMetrics.announcementImageBottomGap
            } else {
                announcementImageView.frame = .zero
            }

            let titleH = titleLabel.sizeThatFits(CGSize(width: bw - 24, height: 200)).height
            titleLabel.frame = CGRect(x: 12, y: y, width: bw - 24, height: ceil(titleH))
            y = titleLabel.frame.maxY + LayoutMetrics.titleBodyGap

            let bodyText = bodyLabel.text ?? ""
            let bodyRect = (bodyText as NSString).boundingRect(
                with: CGSize(width: bw - 24, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: bodyLabel.font ?? UIFont.systemFont(ofSize: 15)],
                context: nil
            )
            let bh = ceil(bodyRect.height)
            bodyLabel.frame = CGRect(x: 12, y: y, width: bw - 24, height: max(1, bh))
            y = bodyLabel.frame.maxY + LayoutMetrics.bodyBottomGap

            if !linkButton.isHidden {
                linkButton.titleLabel?.numberOfLines = 2
                let linkSize = linkButton.sizeThatFits(CGSize(width: bw - 24, height: 120))
                linkButton.frame = CGRect(x: 12, y: y, width: bw - 24, height: ceil(linkSize.height))
                y = linkButton.frame.maxY + LayoutMetrics.linkBottomGap
            } else {
                linkButton.frame = .zero
            }

            let annInset: CGFloat = 12
            let timeTrailingInset: CGFloat = 14
            let footerGap: CGFloat = 8
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
        applyMediaLibraryChromeColors()
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
