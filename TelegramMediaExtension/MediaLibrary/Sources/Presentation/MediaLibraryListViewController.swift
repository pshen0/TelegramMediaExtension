import Combine
import UIKit

/// Список каталога: компактная шапка с градиентом, UISearchBar, вкладки.
final class MediaLibraryListViewController: UITableViewController, UISearchBarDelegate {
    private let store = MediaLibraryStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var filteredItems: [MediaItem] = []
    private var query: String = ""
    private var statusFilter: MediaWatchStatus?
    private var kindFilter: MediaItemKind?

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

    private var navigationControllerViewSavedColor: UIColor?
    /// Чтобы не вызывать `tableHeaderView = …` на каждом layout (риск бесконечного цикла перерасчёта).
    private var lastTableHeaderSize: CGSize = .zero
    private var isUpdatingTableHeader = false

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
        view.backgroundColor = .clear

        tableView.backgroundView = MediaLibraryTableBackgroundView()
        tableView.backgroundColor = .clear
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.separatorColor = TMETheme.Colors.listSeparator
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 112
        tableView.tableFooterView = UIView()
        tableView.register(MediaLibraryItemCell.self, forCellReuseIdentifier: MediaLibraryItemCell.reuseIdentifier)

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
        chromeHeader.folderTabs.onSelectionChange = { [weak self] index in
            self?.applyTabIndex(index)
        }
        tableView.tableHeaderView = chromeHeader

        store.loadIfNeeded()
        bindStore()
        applyFilters()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTransparentNavigationForChrome()
        store.loadIfNeeded()
        applyFilters()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreDefaultNavigationAppearance()
    }

    private func applyTransparentNavigationForChrome() {
        if navigationControllerViewSavedColor == nil {
            navigationControllerViewSavedColor = navigationController?.view.backgroundColor
        }
        navigationController?.view.backgroundColor = .clear

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]

        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance = appearance
        navBar?.scrollEdgeAppearance = appearance
        navBar?.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navBar?.compactScrollEdgeAppearance = appearance
        }
        navBar?.isTranslucent = true
        navBar?.isOpaque = false
        navBar?.setBackgroundImage(UIImage(), for: .default)
        navBar?.shadowImage = UIImage()
        navBar?.tintColor = TMETheme.Colors.accent
    }

    private func restoreDefaultNavigationAppearance() {
        let `default` = UINavigationBarAppearance()
        `default`.configureWithDefaultBackground()

        navigationItem.standardAppearance = nil
        navigationItem.scrollEdgeAppearance = nil
        navigationItem.compactAppearance = nil
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = nil
        }

        let navBar = navigationController?.navigationBar
        navBar?.standardAppearance = `default`
        navBar?.scrollEdgeAppearance = `default`
        navBar?.compactAppearance = `default`
        if #available(iOS 15.0, *) {
            navBar?.compactScrollEdgeAppearance = `default`
        }
        navBar?.setBackgroundImage(nil, for: .default)
        navBar?.shadowImage = nil

        navigationController?.navigationBar.isTranslucent = true
        navigationController?.view.backgroundColor = navigationControllerViewSavedColor
        navigationControllerViewSavedColor = nil
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
    }

    private func layoutEmptyOverlay() {
        emptyOverlay.frame = tableView.frame
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
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty != false {
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        query = ""
        searchBar.setShowsCancelButton(false, animated: true)
        searchBar.resignFirstResponder()
        applyFilters()
    }

    private func applyTabIndex(_ index: Int) {
        if index <= 0 {
            statusFilter = nil
        } else {
            statusFilter = MediaWatchStatus.allCases[index - 1]
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
        let noFilters = query.isEmpty && statusFilter == nil && kindFilter == nil
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
        return UIMenu(children: [filter, sort, grid, search])
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
