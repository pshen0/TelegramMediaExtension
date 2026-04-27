import Combine
import UIKit

final class CommunityListViewController: UITableViewController, UISearchResultsUpdating {
    private let store = CommunityStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var bannerColorObserver: NSObjectProtocol?

    private lazy var communitySearchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Поиск"
        sc.searchBar.autocapitalizationType = .none
        sc.searchBar.autocorrectionType = .yes
        return sc
    }()

    /// Всегда выбран «Сообщества»; выбор другой вкладки сразу откатывается на «Сообщества».
    private let feedSegmentControl: UISegmentedControl = {
        let s = UISegmentedControl(items: ["Все", "Сообщества", "Новые", "Каналы"])
        s.selectedSegmentIndex = 1
        return s
    }()

    private let segmentScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.alwaysBounceVertical = false
        sv.backgroundColor = .clear
        sv.clipsToBounds = true
        return sv
    }()

    /// Отступы: меньше до поиска сверху и до списка чатов снизу; высота дорожки сегмента.
    private enum FeedSegmentMetrics {
        static let controlHeight: CGFloat = 40
        static let topInset: CGFloat = 4
        static let bottomInset: CGFloat = 4
        /// Доп. ширина сегмента кроме текста — больше «воздуха» у плашки выбора от краёв подписи.
        static let segmentInnerHorizontalPadding: CGFloat = 36
        static var headerHeight: CGFloat { topInset + controlHeight + bottomInset }
    }

    private lazy var segmentTableHeaderView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGroupedBackground
        segmentScrollView.translatesAutoresizingMaskIntoConstraints = false
        feedSegmentControl.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(segmentScrollView)
        segmentScrollView.addSubview(feedSegmentControl)
        NSLayoutConstraint.activate([
            segmentScrollView.topAnchor.constraint(equalTo: v.topAnchor, constant: FeedSegmentMetrics.topInset),
            segmentScrollView.bottomAnchor.constraint(equalTo: v.bottomAnchor, constant: -FeedSegmentMetrics.bottomInset),
            segmentScrollView.heightAnchor.constraint(equalToConstant: FeedSegmentMetrics.controlHeight),

            feedSegmentControl.topAnchor.constraint(equalTo: segmentScrollView.contentLayoutGuide.topAnchor),
            feedSegmentControl.bottomAnchor.constraint(equalTo: segmentScrollView.contentLayoutGuide.bottomAnchor),
            feedSegmentControl.leadingAnchor.constraint(equalTo: segmentScrollView.contentLayoutGuide.leadingAnchor),
            feedSegmentControl.trailingAnchor.constraint(equalTo: segmentScrollView.contentLayoutGuide.trailingAnchor),
            feedSegmentControl.heightAnchor.constraint(equalToConstant: FeedSegmentMetrics.controlHeight),
        ])
        feedSegmentControl.addTarget(self, action: #selector(feedSegmentLocked), for: .valueChanged)
        return v
    }()

    /// Горизонталь совпадает с контентной областью таблицы (как у строк и типичной поисковой строки под навбаром).
    private var segmentScrollHorizontalConstraints: [NSLayoutConstraint] = []

    private var lastLaidOutSegmentContainerWidth: CGFloat = 0

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "Чаты"
        definesPresentationContext = true
        navigationItem.searchController = communitySearchController
        navigationItem.hidesSearchBarWhenScrolling = false
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.tableFooterView = UIView()
        tableView.tableHeaderView = segmentTableHeaderView
        pinSegmentScrollHorizontalToTableContent()

        tableView.register(CommunityListCell.self, forCellReuseIdentifier: CommunityListCell.reuseId)

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCommunityTapped))

        store.loadIfNeeded()
        bind()
        applyFeedSegmentAppearance()
    }

    private func pinSegmentScrollHorizontalToTableContent() {
        NSLayoutConstraint.deactivate(segmentScrollHorizontalConstraints)
        /// Горизонталь совпадает с безопасной областью таблицы — как проектная ширина поисковой строки под навбаром.
        let pair = [
            segmentScrollView.leadingAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.leadingAnchor, constant: 15),
            segmentScrollView.trailingAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.trailingAnchor, constant: -15),
        ]
        segmentScrollHorizontalConstraints = pair
        NSLayoutConstraint.activate(pair)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyFeedSegmentAppearance()
    }

    /// 13 pt; подписи не режем — ширины сегментов считаются по тексту + запас; при необходимости горизонтальный скролл.
    private func applyFeedSegmentAppearance() {
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        let primary = UIColor.label
        let segmentAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: primary,
        ]
        feedSegmentControl.setTitleTextAttributes(segmentAttrs, for: .normal)
        feedSegmentControl.setTitleTextAttributes(segmentAttrs, for: .selected)
        feedSegmentControl.selectedSegmentTintColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.11)
                : UIColor.black.withAlphaComponent(0.07)
        }
        if #available(iOS 13.0, *) {
            feedSegmentControl.apportionsSegmentWidthsByContent = false
        }
        lastLaidOutSegmentContainerWidth = 0
        layoutFeedSegmentWidthsIfNeeded()
    }

    /// Растягивает вкладки на ширину контейнера (как один ряд с поиском); если сумма минимальных ширин больше — горизонтальный скролл.
    private func layoutFeedSegmentWidthsIfNeeded() {
        let w = segmentScrollView.bounds.width
        guard w > 1 else { return }
        guard abs(w - lastLaidOutSegmentContainerWidth) > 0.5 else { return }
        lastLaidOutSegmentContainerWidth = w
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        applyFeedSegmentWidths(font: font, containerWidth: w)
    }

    private func applyFeedSegmentWidths(font: UIFont, containerWidth: CGFloat) {
        let pad = FeedSegmentMetrics.segmentInnerHorizontalPadding
        let n = feedSegmentControl.numberOfSegments
        guard n > 0 else { return }

        var baseWidths: [CGFloat] = []
        for i in 0..<n {
            let title = feedSegmentControl.titleForSegment(at: i) ?? ""
            let textW = ceil((title as NSString).size(withAttributes: [.font: font]).width)
            baseWidths.append(max(textW + pad, 52))
        }
        let sumBase = baseWidths.reduce(0, +)

        if containerWidth >= sumBase {
            let extraPer = (containerWidth - sumBase) / CGFloat(n)
            for i in 0..<n {
                feedSegmentControl.setWidth(baseWidths[i] + extraPer, forSegmentAt: i)
            }
        } else {
            for i in 0..<n {
                feedSegmentControl.setWidth(baseWidths[i], forSegmentAt: i)
            }
        }

        segmentTableHeaderView.setNeedsLayout()
        segmentTableHeaderView.layoutIfNeeded()
        feedSegmentControl.invalidateIntrinsicContentSize()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutFeedSegmentWidthsIfNeeded()
        resizeSegmentTableHeaderIfNeeded()
    }

    private func resizeSegmentTableHeaderIfNeeded() {
        guard tableView.tableHeaderView === segmentTableHeaderView else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let height = FeedSegmentMetrics.headerHeight
        let header = segmentTableHeaderView
        if abs(header.frame.width - width) > 0.5 || abs(header.frame.height - height) > 0.5 {
            header.frame = CGRect(x: 0, y: 0, width: width, height: height)
            tableView.tableHeaderView = header
        }
    }

    @objc private func feedSegmentLocked(_ sender: UISegmentedControl) {
        guard sender.selectedSegmentIndex != 1 else { return }
        sender.selectedSegmentIndex = 1
    }

    func updateSearchResults(for searchController: UISearchController) {
        tableView.reloadData()
    }

    private func displayedCommunities() -> [CommunityChat] {
        let trimmed = communitySearchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return store.communities
        }
        let q = trimmed.lowercased()
        return store.communities.filter { c in
            if c.title.lowercased().contains(q) { return true }
            let preview = store.listPreviewText(for: c.id)
            return preview.lowercased().contains(q)
        }
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

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayedCommunities().count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommunityListCell.rowHeight()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommunityListCell.reuseId, for: indexPath) as! CommunityListCell
        let c = displayedCommunities()[indexPath.row]
        let preview = store.listPreviewText(for: c.id)
        let last = store.lastMessage(for: c.id)
        let timeText = last.map { Self.formatListTime($0.createdAt) } ?? ""
        cell.configure(community: c, preview: preview, timeText: timeText)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = displayedCommunities()[indexPath.row]
        navigationController?.pushViewController(CommunityChatViewController(communityId: c.id), animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let c = displayedCommunities()[indexPath.row]
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
        let titleToSubtitle: CGFloat = 4
        let titleLineH: CGFloat = 22
        let bodyFont = subtitleLabel.font ?? TMETheme.Fonts.body(15)
        let subtitleTwoLineH = ceil(bodyFont.lineHeight * 2 + 1)

        /// Вертикальное центрирование аватара: одинаковый зазор от верха/низа плашки до круга.
        let avatarY = floor((b.height - avatarSide) / 2)
        let titleY = avatarY

        timeLabel.sizeToFit()
        let timeW = timeLabel.isHidden ? 0 : min(88, max(28, ceil(timeLabel.bounds.width)))
        let timeX = b.width - mr - timeW
        timeLabel.frame = CGRect(x: timeX, y: titleY, width: timeW, height: titleLineH)

        let avatarX = ml
        avatarView.frame = CGRect(x: avatarX, y: avatarY, width: avatarSide, height: avatarSide)

        let textLeft = avatarX + avatarSide + gap
        let textRightEdge = timeLabel.isHidden ? b.width - mr : timeX - gap
        let textW = max(0, textRightEdge - textLeft)

        titleLabel.frame = CGRect(x: textLeft, y: titleY, width: textW, height: titleLineH)

        let subY = titleY + titleLineH + titleToSubtitle
        subtitleLabel.frame = CGRect(x: textLeft, y: subY, width: textW, height: subtitleTwoLineH)
    }
}
