import UIKit

/// Вкладка «Поиск в базах»: строка поиска + результаты (заглушка API).
final class MediaCatalogSearchViewController: UITableViewController, UISearchBarDelegate {
    private let interactor: MediaCatalogSearchBusinessLogic
    weak var addFlowCoordinator: AddToMediaLibraryViewController?
    var onSelectCandidate: ((MediaCatalogCandidate) -> Void)?

    private let searchBar = UISearchBar()
    private var rows: [MediaCatalogSearchModel.List.Row] = []
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    init(style: UITableView.Style, interactor: MediaCatalogSearchBusinessLogic) {
        self.interactor = interactor
        super.init(style: style)
    }

    override init(style: UITableView.Style) {
        let presenter = MediaCatalogSearchPresenter()
        let interactor = MediaCatalogSearchInteractor(presenter: presenter)
        self.interactor = interactor
        super.init(style: style)
        presenter.view = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cand")
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        searchBar.placeholder = "Название фильма, сериала, книги…"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        tableView.tableHeaderView = searchBar

        interactor.viewDidLoad(.init())
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = tableView.bounds.width
        guard w > 0 else { return }
        let h = searchBar.sizeThatFits(CGSize(width: w, height: 120)).height
        if searchBar.frame.width != w || abs(searchBar.frame.height - h) > 0.5 {
            searchBar.frame = CGRect(x: 0, y: 0, width: w, height: h)
            tableView.tableHeaderView = searchBar
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cand", for: indexPath)
        let row = rows[indexPath.row]
        var conf = UIListContentConfiguration.subtitleCell()
        conf.text = row.candidate.title
        conf.secondaryText = row.secondaryText
        conf.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = conf
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = rows[indexPath.row].candidate
        if let onSelectCandidate {
            onSelectCandidate(c)
            return
        }
        let preview = MediaCatalogPreviewBuilder.build(candidate: c)
        preview.addFlowCoordinator = addFlowCoordinator
        navigationController?.pushViewController(preview, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        interactor.queryChanged(.init(query: searchText))
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - MediaCatalogSearchDisplayLogic

extension MediaCatalogSearchViewController: MediaCatalogSearchDisplayLogic {
    func displayList(_ viewModel: MediaCatalogSearchModel.List.ViewModel) {
        rows = viewModel.rows
        tableView.reloadData()
    }
}
