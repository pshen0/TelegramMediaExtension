import UIKit

/// Вкладка «Поиск в базах»: строка поиска + результаты (заглушка API).
final class MediaCatalogSearchViewController: UITableViewController, UISearchBarDelegate {
    weak var addFlowCoordinator: AddToMediaLibraryViewController?

    private let searchBar = UISearchBar()
    private var results: [MediaCatalogCandidate] = []
    private var searchTask: Task<Void, Never>?
    private let keyboardDismissOnTapOutside = MediaLibraryKeyboardDismissOnTapOutside()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cand")
        tableView.keyboardDismissMode = .interactive
        keyboardDismissOnTapOutside.attach(to: view)

        searchBar.placeholder = "Название фильма, сериала, книги…"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        tableView.tableHeaderView = searchBar
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
        results.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cand", for: indexPath)
        let c = results[indexPath.row]
        var conf = UIListContentConfiguration.subtitleCell()
        conf.text = c.title
        conf.secondaryText = [c.kind.title, c.year.map(String.init), c.genre].compactMap { $0 }.joined(separator: " · ")
        conf.secondaryTextProperties.numberOfLines = 2
        cell.contentConfiguration = conf
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = results[indexPath.row]
        let preview = MediaCatalogPreviewViewController(candidate: c)
        preview.addFlowCoordinator = addFlowCoordinator
        navigationController?.pushViewController(preview, animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTask?.cancel()
        let q = searchText
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let list = await MediaCatalogSearchService.search(query: q)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.results = list
                self?.tableView.reloadData()
            }
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
