import Combine
import UIKit

final class MyAnnouncementsViewController: UITableViewController {
    private let store = CommunityStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Мои анонсы"
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        store.loadIfNeeded()
        bind()
    }

    private func bind() {
        store.$savedAnnouncements
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.savedAnnouncements.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let a = store.savedAnnouncements[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = a.title
        content.secondaryText = Self.formatDate(a.date)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let a = store.savedAnnouncements[indexPath.row]
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
