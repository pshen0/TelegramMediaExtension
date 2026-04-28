import UIKit

final class CommunityListViewController: UITableViewController, UISearchResultsUpdating {
    private let interactor: CommunityListInteractor
    private var rows: [CommunityListModel.List.Row] = []
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

    // Всегда выбран «Сообщества»; выбор другой вкладки сразу откатывается на «Сообщества».
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

    private enum FeedSegmentMetrics {
        static let controlHeight: CGFloat = 40
        static let topInset: CGFloat = 4
        static let bottomInset: CGFloat = 4
        static let segmentInnerHorizontalPadding: CGFloat = 36
        static var headerHeight: CGFloat { topInset + controlHeight + bottomInset }
    }

    private lazy var segmentTableHeaderView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGroupedBackground
        v.addSubview(segmentScrollView)
        segmentScrollView.addSubview(feedSegmentControl)

        segmentScrollView.pinTop(to: v.topAnchor, Double(FeedSegmentMetrics.topInset))
        segmentScrollView.pinBottom(to: v.bottomAnchor, Double(FeedSegmentMetrics.bottomInset))
        segmentScrollView.setHeight(Double(FeedSegmentMetrics.controlHeight))

        feedSegmentControl.pinTop(to: segmentScrollView.contentLayoutGuide.topAnchor)
        feedSegmentControl.pinBottom(to: segmentScrollView.contentLayoutGuide.bottomAnchor)
        feedSegmentControl.pinLeft(to: segmentScrollView.contentLayoutGuide.leadingAnchor)
        feedSegmentControl.pinRight(to: segmentScrollView.contentLayoutGuide.trailingAnchor)
        feedSegmentControl.setHeight(Double(FeedSegmentMetrics.controlHeight))

        feedSegmentControl.addTarget(self, action: #selector(feedSegmentLocked), for: .valueChanged)
        return v
    }()

    private var segmentScrollHorizontalConstraints: [NSLayoutConstraint] = []

    private var lastLaidOutSegmentContainerWidth: CGFloat = 0

    convenience init() {
        let presenter = CommunityListPresenter()
        let interactor = CommunityListInteractor(presenter: presenter)
        self.init(interactor: interactor)
        presenter.view = self
        interactor.router = self
    }

    init(interactor: CommunityListInteractor) {
        self.interactor = interactor
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

        interactor.viewDidLoad(CommunityListModel.ViewDidLoad.Request())
        applyFeedSegmentAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        interactor.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        interactor.viewWillDisappear()
    }

    private func pinSegmentScrollHorizontalToTableContent() {
        NSLayoutConstraint.deactivate(segmentScrollHorizontalConstraints)
        let leading = segmentScrollView.pinLeft(to: tableView.safeAreaLayoutGuide.leadingAnchor, 15)
        let trailing = segmentScrollView.pinRight(to: tableView.safeAreaLayoutGuide.trailingAnchor, 15)
        segmentScrollHorizontalConstraints = [leading, trailing]
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyFeedSegmentAppearance()
    }

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
        let q = communitySearchController.searchBar.text ?? ""
        interactor.updateSearch(CommunityListModel.UpdateSearch.Request(query: q))
    }

    deinit {
        if let bannerColorObserver {
            NotificationCenter.default.removeObserver(bannerColorObserver)
        }
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
            self.interactor.createCommunity(CommunityListModel.CreateCommunity.Request(title: title))
        })
        present(ac, animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        CommunityListCell.rowHeight()
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommunityListCell.reuseId, for: indexPath) as! CommunityListCell
        let row = rows[indexPath.row]
        cell.configure(
            community: row.community,
            preview: row.preview,
            timeText: row.timeText,
            previewIsHiddenSpoiler: row.previewIsHiddenSpoiler
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        if row.kind == .discover {
            communitySearchController.searchBar.text = ""
            communitySearchController.isActive = false
            interactor.updateSearch(CommunityListModel.UpdateSearch.Request(query: ""))
        }
        interactor.selectRow(CommunityListModel.SelectRow.Request(row: row))
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard rows[indexPath.row].kind == .member else { return nil }
        let id = rows[indexPath.row].community.id
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, done in
            self?.interactor.deleteCommunity(CommunityListModel.DeleteCommunity.Request(id: id))
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - CommunityListDisplayLogic

extension CommunityListViewController: CommunityListDisplayLogic {
    func displayCommunityList(_ viewModel: CommunityListModel.List.ViewModel) {
        rows = viewModel.rows
        tableView.reloadData()
    }
}

// MARK: - CommunityListRoutingLogic

extension CommunityListViewController: CommunityListRoutingLogic {
    func routeToChat(communityId: UUID) {
        navigationController?.pushViewController(CommunityChatBuilder.build(communityId: communityId), animated: true)
    }
}
