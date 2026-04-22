import Combine
import UIKit

final class CommunityListViewController: UITableViewController {
    private let store = CommunityStore.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Сообщества"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorColor = TMETheme.Colors.listSeparator
        tableView.tableFooterView = UIView()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "calendar"), style: .plain, target: self, action: #selector(myAnnouncementsTapped)),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addCommunityTapped))
        ]
        navigationItem.rightBarButtonItems?.first?.accessibilityLabel = "Мои анонсы"

        store.loadIfNeeded()
        bind()
    }

    private func bind() {
        store.$communities
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

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let c = store.communities[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = c.title
        content.secondaryText = "Посты и анонсы"
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.backgroundConfiguration = UIBackgroundConfiguration.listPlainCell()
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
}
