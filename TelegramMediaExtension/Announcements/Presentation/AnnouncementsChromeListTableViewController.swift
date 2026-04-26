import Combine
import UIKit

/// Список сохранённых анонсов с шапкой как в медиатеке (`MediaLibraryChromeHeaderView`) и поиском.
class AnnouncementsChromeListTableViewController: UITableViewController, UISearchBarDelegate {
    enum SearchScope {
        case titleOnly
        case titleDetailsLink
    }

    private let listTitle: String
    private let searchPlaceholder: String
    private let searchScope: SearchScope

    private let store = CommunityStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var filtered: [SavedAnnouncement] = []
    private var query: String = ""

    private let chromeHeader = MediaLibraryChromeHeaderView()
    private var lastTableHeaderSize: CGSize = .zero
    private var isUpdatingTableHeader = false
    private var bannerColorObserver: NSObjectProtocol?
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    init(listTitle: String, searchPlaceholder: String, searchScope: SearchScope) {
        self.listTitle = listTitle
        self.searchPlaceholder = searchPlaceholder
        self.searchScope = searchScope
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = listTitle

        edgesForExtendedLayout = [.top]
        view.backgroundColor = MediaLibraryHeaderBannerColor.resolved(for: traitCollection)

        tableView.backgroundView = MediaLibraryTableBackgroundView()
        tableView.backgroundColor = .clear
        tableView.clipsToBounds = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.tableFooterView = UIView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPersonalAnnouncementTapped))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Новый анонс"

        chromeHeader.showsFolderTabs = false
        chromeHeader.searchBar.placeholder = searchPlaceholder
        chromeHeader.searchBar.delegate = self
        chromeHeader.onBannerTap = { [weak self] in
            self?.presentBannerColorPicker()
        }
        chromeHeader.onSearchDismiss = { [weak self] in
            self?.dismissSearchKeyboardAndClear()
        }
        tableView.tableHeaderView = chromeHeader

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyBannerChromeColors()
        }

        store.loadIfNeeded()
        bind()
        applyFilter()
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    private func bind() {
        store.$savedAnnouncements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyBannerChromeColors()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyChromeNavigationAppearance()
        store.loadIfNeeded()
        applyFilter()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreDefaultNavigationAppearance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tableW = tableView.bounds.width
        guard tableW > 0 else { return }
        guard !isUpdatingTableHeader else { return }

        var topSafe = view.safeAreaInsets.top
        if topSafe < 2, let window = view.window {
            let navH = navigationController?.navigationBar.frame.height ?? 44
            topSafe = max(topSafe, window.safeAreaInsets.top + navH)
        }
        chromeHeader.setTopSafeInset(topSafe)

        let bottomSafe = view.safeAreaInsets.bottom
        if tableView.contentInset.bottom != bottomSafe {
            tableView.contentInset.bottom = bottomSafe
            tableView.verticalScrollIndicatorInsets.bottom = bottomSafe
        }

        let headerH = chromeHeader.preferredHeight(forWidth: tableW)
        let newSize = CGSize(width: tableW, height: headerH)
        let sizeChanged =
            lastTableHeaderSize == .zero
            || abs(newSize.width - lastTableHeaderSize.width) > 0.5
            || abs(newSize.height - lastTableHeaderSize.height) > 0.5

        if sizeChanged {
            isUpdatingTableHeader = true
            lastTableHeaderSize = newSize
            chromeHeader.frame = CGRect(origin: .zero, size: newSize)
            tableView.tableHeaderView = chromeHeader
            isUpdatingTableHeader = false
        }
        updateHeaderScrollFade()
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateHeaderScrollFade()
    }

    private func chromeBlendNavigationSurfaceColor(scrollProgress p: CGFloat) -> UIColor {
        let t = min(1, max(0, p))
        return UIColor { tc in
            let banner = MediaLibraryHeaderBannerColor.resolved(for: tc).resolvedColor(with: tc)
            let flat = UIColor.systemBackground.resolvedColor(with: tc)
            let tn = CGFloat(t)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            guard banner.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
                  flat.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
                return tn < 0.5 ? banner : flat
            }
            return UIColor(
                red: r1 + (r2 - r1) * tn,
                green: g1 + (g2 - g1) * tn,
                blue: b1 + (b2 - b1) * tn,
                alpha: a1 + (a2 - a1) * tn
            )
        }
    }

    private func transparentChromeNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        return appearance
    }

    private func applyChromeNavigationForScrollProgress(_ progress: CGFloat) {
        view.backgroundColor = chromeBlendNavigationSurfaceColor(scrollProgress: progress)
        let appearance = transparentChromeNavigationBarAppearance()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }
        navigationController?.navigationBar.tintColor = TMETheme.Colors.accent
    }

    private func applyChromeNavigationAppearance() {
        updateHeaderScrollFade()
    }

    private func restoreDefaultNavigationAppearance() {
        navigationItem.standardAppearance = nil
        navigationItem.scrollEdgeAppearance = nil
        navigationItem.compactAppearance = nil
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = nil
        }
    }

    private func applyBannerChromeColors() {
        chromeHeader.refreshBannerBackgroundColor()
        updateHeaderScrollFade()
    }

    private func updateHeaderScrollFade() {
        let progress = computeScrollFadeProgress()
        chromeHeader.setScrollFadeProgress(progress)
        applyChromeNavigationForScrollProgress(progress)
    }

    private func computeScrollFadeProgress() -> CGFloat {
        let y = tableView.contentOffset.y
        let w = tableView.bounds.width
        guard w > 0 else { return 0 }
        let coloredH = chromeHeader.coloredBannerHeight(forWidth: w)
        let fadeDistance = max(44, coloredH)
        if y <= 0 { return 0 }
        return min(1, y / fadeDistance)
    }

    private func presentBannerColorPicker() {
        let picker = MediaLibraryBannerColorPickerViewController()
        picker.onFinish = { [weak self] in
            self?.applyBannerChromeColors()
        }
        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 16.0, *) {
            let sheet = nav.sheetPresentationController
            sheet?.prefersGrabberVisible = true
            sheet?.preferredCornerRadius = 16
            sheet?.prefersEdgeAttachedInCompactHeight = true
            sheet?.widthFollowsPreferredContentSizeWhenEdgeAttached = false
            let colorSheetId = UISheetPresentationController.Detent.Identifier("bannerColorSheetAnnouncements")
            let colorDetent = UISheetPresentationController.Detent.custom(identifier: colorSheetId) { context in
                context.maximumDetentValue / 4.5
            }
            sheet?.detents = [colorDetent]
            sheet?.selectedDetentIdentifier = colorSheetId
            sheet?.prefersScrollingExpandsWhenScrolledToEdge = false
        } else if #available(iOS 15.0, *) {
            nav.sheetPresentationController?.detents = [.medium()]
            nav.sheetPresentationController?.prefersGrabberVisible = true
        }
        let navBarAppear = UINavigationBarAppearance()
        navBarAppear.configureWithTransparentBackground()
        navBarAppear.shadowColor = .clear
        nav.navigationBar.standardAppearance = navBarAppear
        nav.navigationBar.scrollEdgeAppearance = navBarAppear
        nav.navigationBar.compactAppearance = navBarAppear
        nav.navigationBar.compactScrollEdgeAppearance = navBarAppear
        nav.navigationBar.isTranslucent = true
        present(nav, animated: true)
    }

    @objc private func addPersonalAnnouncementTapped() {
        let vc = NewAnnouncementViewController(personal: ())
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    private func applyFilter() {
        let q = query.lowercased()
        let base = store.savedAnnouncements
        if q.isEmpty {
            filtered = base
        } else {
            switch searchScope {
            case .titleOnly:
                filtered = base.filter { $0.title.lowercased().contains(q) }
            case .titleDetailsLink:
                filtered = base.filter { a in
                    if a.title.lowercased().contains(q) { return true }
                    if (a.details ?? "").lowercased().contains(q) { return true }
                    if (a.linkURL ?? "").lowercased().contains(q) { return true }
                    return false
                }
            }
        }
        tableView.reloadData()
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilter()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: false)
        chromeHeader.setShowsSearchDismiss(true, animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        chromeHeader.setShowsSearchDismiss(false, animated: true)
        if searchBar.text?.isEmpty != false {
            searchBar.setShowsCancelButton(false, animated: false)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func dismissSearchKeyboardAndClear() {
        chromeHeader.searchBar.text = ""
        query = ""
        chromeHeader.searchBar.searchTextField.resignFirstResponder()
        chromeHeader.setShowsSearchDismiss(false, animated: true)
        applyFilter()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let a = filtered[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = a.title
        content.secondaryText = Self.formatDate(a.date)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        var bg = UIBackgroundConfiguration.listPlainCell()
        bg.backgroundColor = .systemBackground
        cell.backgroundConfiguration = bg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let a = filtered[indexPath.row]
        navigationController?.pushViewController(SavedAnnouncementDetailViewController(announcement: a), animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let a = filtered[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            self?.store.deleteSavedAnnouncement(id: a.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
