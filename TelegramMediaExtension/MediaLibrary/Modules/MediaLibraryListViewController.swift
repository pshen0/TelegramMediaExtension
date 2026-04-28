import Combine
import UIKit

/// Список каталога: шапка в стиле профиля (сплошной цвет), UISearchBar, вкладки.
final class MediaLibraryListViewController: UITableViewController, UISearchBarDelegate {
    private let store = MediaLibraryStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var filteredItems: [MediaItem] = []
    private var query: String = ""
    private var statusFilter: MediaWatchStatus?
    private var kindFilter: MediaItemKind?
    private var favoritesOnly: Bool = false

    private enum LibrarySort {
        case updatedDesc
        case titleAsc

        var title: String {
            switch self {
            case .updatedDesc: return "Сначала новые по дате"
            case .titleAsc: return "По названию (А–Я)"
            }
        }
    }

    private var librarySort: LibrarySort = .updatedDesc

    private var overflowBarButton: UIBarButtonItem!

    private let chromeHeader = MediaLibraryChromeHeaderView()
    private let emptyOverlay = MediaLibraryEmptyStateView()

    /// Чтобы не вызывать `tableHeaderView = …` на каждом layout (риск бесконечного цикла перерасчёта).
    private var lastTableHeaderSize: CGSize = .zero
    private var isUpdatingTableHeader = false

    private var bannerColorObserver: NSObjectProtocol?
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "Медиатека"

        edgesForExtendedLayout = [.top]
        view.backgroundColor = MediaLibraryHeaderBannerColor.resolved(for: traitCollection)

        tableView.backgroundView = MediaLibraryTableBackgroundView()
        tableView.backgroundColor = .clear
        tableView.clipsToBounds = false
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 128
        tableView.tableFooterView = UIView()
        tableView.register(MediaLibraryItemCell.self, forCellReuseIdentifier: MediaLibraryItemCell.reuseIdentifier)
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        let add = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        overflowBarButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: nil, action: nil)
        overflowBarButton.accessibilityLabel = "Ещё"
        overflowBarButton.menu = buildOverflowMenu()

        if navigationController?.presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Готово", style: .done, target: self, action: #selector(doneTapped))
        } else {
            navigationItem.leftBarButtonItem = nil
        }
        navigationItem.rightBarButtonItems = [add, overflowBarButton]

        emptyOverlay.isHidden = true
        view.insertSubview(emptyOverlay, aboveSubview: tableView)

        chromeHeader.searchBar.delegate = self
        chromeHeader.onBannerTap = { [weak self] in
            self?.presentBannerColorPicker()
        }
        chromeHeader.onSearchDismiss = { [weak self] in
            self?.dismissSearchKeyboardAndClear()
        }
        chromeHeader.folderTabs.onSelectionChange = { [weak self] index in
            self?.applyTabIndex(index)
        }
        tableView.tableHeaderView = chromeHeader

        bannerColorObserver = NotificationCenter.default.addObserver(
            forName: .mediaLibraryBannerColorDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyBannerChromeColors()
        }

        bindStore()
        applyFilters()

        Task { [weak self] in
            guard let self else { return }
            await self.store.loadIfNeededAsync()
            self.applyFilters()
        }
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyBannerChromeColors()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyChromeNavigationAppearance()
        applyFilters()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreDefaultNavigationAppearance()
    }

    /// Плавный переход цвета навбара и подложки из акцента шапки в `systemBackground`, чтобы при скролле не оставалась цветная полоса под статус-баром.
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

    /// Только через `navigationItem`: не трогаем общий `UINavigationBar`, чтобы при push другие экраны не «наследовали» цвет шапки медиатеки.
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
        for cell in tableView.visibleCells {
            (cell as? MediaLibraryItemCell)?.refreshPlaceholderIfNeeded()
        }
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
            let colorSheetId = UISheetPresentationController.Detent.Identifier("bannerColorSheet")
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        defer { layoutEmptyOverlay() }

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
        if !emptyOverlay.isHidden {
            layoutEmptyOverlay()
        }
    }

    /// Полное затухание цветной полосы и совпадение навбара с фоном списка после прокрутки высоты цветного баннера.
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

        if y <= 0 {
            return 0
        }
        return min(1, y / fadeDistance)
    }

    private func layoutEmptyOverlay() {
        emptyOverlay.frame = tableView.frame
        emptyOverlay.bottomSafeInset = view.safeAreaInsets.bottom
        guard let header = tableView.tableHeaderView else {
            emptyOverlay.headerBottomY = 0
            return
        }
        let bottomInHeader = CGPoint(x: header.bounds.midX, y: header.bounds.maxY)
        let inTableCoords = header.convert(bottomInHeader, to: tableView)
        let inOverlay = tableView.convert(inTableCoords, to: emptyOverlay)
        emptyOverlay.headerBottomY = max(0, inOverlay.y)
    }

    private func bindStore() {
        store.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilters()
            }
            .store(in: &cancellables)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        applyFilters()
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
        applyFilters()
    }

    private func applyTabIndex(_ index: Int) {
        if index <= 0 {
            favoritesOnly = false
            statusFilter = nil
        } else if index == 1 {
            favoritesOnly = true
            statusFilter = nil
        } else {
            favoritesOnly = false
            statusFilter = MediaWatchStatus.allCases[index - 2]
        }
        applyFilters()
    }

    @objc private func addTapped() {
        navigationController?.pushViewController(AddToMediaLibraryViewController(), animated: true)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    private func applyFilters() {
        let items = store.items
        let q = query.lowercased()

        var result = items

        if favoritesOnly {
            result = result.filter(\.isFavorite)
        }

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        if let kindFilter {
            result = result.filter { $0.kind == kindFilter }
        }

        if !q.isEmpty {
            let hashtagQuery: String? = {
                if q.hasPrefix("#") { return String(q.dropFirst()) }
                return nil
            }()

            result = result.filter { item in
                if item.title.lowercased().contains(q) { return true }
                if let hashtagQuery {
                    return item.hashtags.contains(where: { $0.lowercased().contains(hashtagQuery) })
                }
                return item.hashtags.contains(where: { ("#" + $0).lowercased().contains(q) })
            }
        }

        switch librarySort {
        case .updatedDesc:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .titleAsc:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        filteredItems = result
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let empty = filteredItems.isEmpty
        emptyOverlay.isHidden = !empty
        guard empty else { return }
        let total = store.totalItemCount()
        let noFilters = query.isEmpty && statusFilter == nil && kindFilter == nil && favoritesOnly == false
        emptyOverlay.mode = (total == 0 && noFilters) ? .libraryEmpty : .filteredEmpty
    }

    private func buildOverflowMenu() -> UIMenu {
        let filter = UIAction(title: "Тип контента", image: UIImage(systemName: "line.3.horizontal.decrease.circle")) { [weak self] _ in
            self?.presentKindFilterSheet()
        }
        let sort = UIAction(title: "Сортировка", image: UIImage(systemName: "arrow.up.arrow.down.circle")) { [weak self] _ in
            self?.presentSortSheet()
        }
        let grid = UIAction(title: "Сетка", image: UIImage(systemName: "square.grid.2x2")) { [weak self] _ in
            self?.openGrid()
        }
        let search = UIAction(title: "Найти в списке", image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
            self?.chromeHeader.searchBar.becomeFirstResponder()
        }
        let announcements = UIAction(title: "Анонсы", image: UIImage(systemName: "calendar")) { [weak self] _ in
            self?.navigationController?.pushViewController(AnnouncementsChromeListBuilder.mediaLibraryAnnouncements(), animated: true)
        }
        return UIMenu(children: [announcements, filter, sort, grid, search])
    }

    private func presentKindFilterSheet() {
        let ac = UIAlertController(title: "Тип контента", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "Все типы", style: .default) { [weak self] _ in
            self?.kindFilter = nil
            self?.applyFilters()
        })
        for k in MediaItemKind.allCases {
            ac.addAction(UIAlertAction(title: k.title, style: .default) { [weak self] _ in
                self?.kindFilter = k
                self?.applyFilters()
            })
        }
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.popoverPresentationController?.barButtonItem = overflowBarButton
        present(ac, animated: true)
    }

    private func presentSortSheet() {
        let ac = UIAlertController(title: "Сортировка", message: nil, preferredStyle: .actionSheet)
        for option: LibrarySort in [.updatedDesc, .titleAsc] {
            let title = librarySort == option ? "✓ \(option.title)" : option.title
            ac.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.librarySort = option
                self?.applyFilters()
            })
        }
        ac.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        ac.popoverPresentationController?.barButtonItem = overflowBarButton
        present(ac, animated: true)
    }

    private func openGrid() {
        let grid = MediaLibraryGridViewController()
        grid.itemsProvider = { [weak self] in self?.filteredItems ?? [] }
        navigationController?.pushViewController(grid, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MediaLibraryItemCell.reuseIdentifier, for: indexPath) as! MediaLibraryItemCell
        cell.configure(item: filteredItems[indexPath.row])
        var bg = UIBackgroundConfiguration.listPlainCell()
        bg.backgroundColor = .systemBackground
        cell.backgroundConfiguration = bg
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = filteredItems[indexPath.row]
        return item.hashtags.isEmpty ? 96 : 124
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        navigationController?.pushViewController(MediaItemDetailViewController(item: item), animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = filteredItems[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            self?.store.delete(id: item.id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
