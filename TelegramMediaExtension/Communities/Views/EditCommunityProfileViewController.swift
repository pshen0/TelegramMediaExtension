import PhotosUI
import SafariServices
import UIKit

final class EditCommunityProfileViewController: UITableViewController, PHPickerViewControllerDelegate {
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
