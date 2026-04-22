import Combine
import UIKit

final class CommunityListViewController: UITableViewController {
    private let store = CommunityStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var bannerColorObserver: NSObjectProtocol?

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "Сообщества"
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.tableFooterView = UIView()

        tableView.register(CommunityListCell.self, forCellReuseIdentifier: CommunityListCell.reuseId)

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "calendar"), style: .plain, target: self, action: #selector(myAnnouncementsTapped)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCommunityTapped))
        ]
        navigationItem.rightBarButtonItems?.first?.accessibilityLabel = "Мои анонсы"

        store.loadIfNeeded()
        bind()
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    private func bind() {
        store.$communities
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        store.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    @objc private func addCommunityTapped() {
        let ac = UIAlertController(title: "Новое сообщество", message: "Название", preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = "Например: Dune (книга)"
            tf.autocapitalizationType = .sentences
        }
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.addAction(UIAlertAction(title: "Создать", style: .default) { [weak self] _ in
            guard let self else { return }
            let title = ac.textFields?.first?.text ?? ""
            let c = self.store.createCommunity(title: title)
            self.navigationController?.pushViewController(CommunityChatViewController(communityId: c.id), animated: true)
        })
        present(ac, animated: true)
    }

    @objc private func myAnnouncementsTapped() {
        navigationController?.pushViewController(MyAnnouncementsViewController(), animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.communities.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommunityListCell.rowHeight()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommunityListCell.reuseId, for: indexPath) as! CommunityListCell
        let c = store.communities[indexPath.row]
        let preview = store.listPreviewText(for: c.id)
        let last = store.lastMessage(for: c.id)
        let timeText = last.map { Self.formatListTime($0.createdAt) } ?? ""
        cell.configure(community: c, preview: preview, timeText: timeText)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = store.communities[indexPath.row]
        navigationController?.pushViewController(CommunityChatViewController(communityId: c.id), animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let c = store.communities[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            self?.store.deleteCommunity(id: c.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    private static func formatListTime(_ date: Date) -> String {
        let cal = Calendar.current
        let fTime = DateFormatter()
        fTime.locale = Locale(identifier: "ru_RU")
        fTime.dateFormat = "HH:mm"
        if cal.isDateInToday(date) {
            return fTime.string(from: date)
        }
        if cal.isDateInYesterday(date) {
            return "Вчера"
        }
        let fDay = DateFormatter()
        fDay.locale = Locale(identifier: "ru_RU")
        if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            fDay.dateFormat = "d MMM"
        } else {
            fDay.dateFormat = "d.MM.yy"
        }
        return fDay.string(from: date)
    }
}

// MARK: - Cell

private final class CommunityListCell: UITableViewCell {
    static let reuseId = "CommunityListCell"

    private var usesAvatarPlaceholder = false
    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()

    static func rowHeight() -> CGFloat {
        let vTop: CGFloat = 8
        let vBottom: CGFloat = 8
        let titleLine: CGFloat = 22
        let titleToSubtitle: CGFloat = 4
        let body = TMETheme.Fonts.body(15)
        let subtitleTwoLines = ceil(body.lineHeight * 2 + 1)
        return vTop + titleLine + titleToSubtitle + subtitleTwoLines + vBottom
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        accessoryType = .none
        backgroundColor = .systemGroupedBackground
        contentView.backgroundColor = .systemGroupedBackground

        avatarView.layer.cornerRadius = 26
        if #available(iOS 13.0, *) {
            avatarView.layer.cornerCurve = .continuous
        }
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.isUserInteractionEnabled = false
        avatarView.accessibilityIgnoresInvertColors = true

        titleLabel.font = TMETheme.Fonts.titleSemibold(17)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.font = TMETheme.Fonts.body(15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = TMETheme.Fonts.body(13)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.numberOfLines = 1
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)

        contentView.addSubview(avatarView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(timeLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        usesAvatarPlaceholder = false
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if usesAvatarPlaceholder {
            applyAvatarPlaceholderChrome()
        }
    }

    private func applyAvatarPlaceholderChrome() {
        avatarView.tintColor = MediaLibraryHeaderBannerColor.posterPlaceholderTint(for: traitCollection)
        avatarView.backgroundColor = MediaLibraryHeaderBannerColor.posterPlaceholderFill(for: traitCollection)
    }

    func configure(community: CommunityChat, preview: String, timeText: String) {
        titleLabel.text = community.title
        subtitleLabel.text = preview
        timeLabel.text = timeText
        timeLabel.isHidden = timeText.isEmpty

        if let name = community.avatarFileName,
           let url = CommunityStore.communityAvatarURL(fileName: name),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            usesAvatarPlaceholder = false
            avatarView.contentMode = .scaleAspectFill
            avatarView.image = img.withRenderingMode(.alwaysOriginal)
            avatarView.tintColor = nil
            avatarView.backgroundColor = .clear
        } else {
            usesAvatarPlaceholder = true
            avatarView.contentMode = .center
            let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            avatarView.image = UIImage(systemName: "person.2.fill", withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate)
            applyAvatarPlaceholderChrome()
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = contentView.bounds
        let ml = contentView.layoutMargins.left
        let mr = contentView.layoutMargins.right
        let avatarSide: CGFloat = 52
        let gap: CGFloat = 12
        let topPad: CGFloat = 8
        let titleToSubtitle: CGFloat = 4
        let titleLineH: CGFloat = 22
        let bodyFont = subtitleLabel.font ?? TMETheme.Fonts.body(15)
        let subtitleTwoLineH = ceil(bodyFont.lineHeight * 2 + 1)

        timeLabel.sizeToFit()
        let timeW = timeLabel.isHidden ? 0 : min(88, max(28, ceil(timeLabel.bounds.width)))
        let timeX = b.width - mr - timeW
        timeLabel.frame = CGRect(x: timeX, y: topPad, width: timeW, height: titleLineH)

        let avatarX = ml
        let avatarY = topPad
        avatarView.frame = CGRect(x: avatarX, y: avatarY, width: avatarSide, height: avatarSide)

        let textLeft = avatarX + avatarSide + gap
        let textRightEdge = timeLabel.isHidden ? b.width - mr : timeX - gap
        let textW = max(0, textRightEdge - textLeft)

        titleLabel.frame = CGRect(x: textLeft, y: topPad, width: textW, height: titleLineH)

        let subY = topPad + titleLineH + titleToSubtitle
        subtitleLabel.frame = CGRect(x: textLeft, y: subY, width: textW, height: subtitleTwoLineH)
    }
}
