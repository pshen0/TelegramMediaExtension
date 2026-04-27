import UIKit

final class TMERouterViewController: UITableViewController {
    private struct Row {
        let title: String
        let subtitle: String?
        let build: () -> UIViewController
    }
    
    private lazy var rows: [Row] = [
        Row(
            title: "Медиатека",
            subtitle: "Каталог: тип, статус, прогресс, заметки, хэштеги",
            build: { MediaLibraryBuilder.build() }
        ),
        Row(
            title: "Сообщества",
            subtitle: "Посты и анонсы, сохранение анонсов",
            build: { CommunitiesBuilder.build() }
        ),
        Row(
            title: "Мои анонсы",
            subtitle: "Сохранённые из сообществ, сортировка по дате",
            build: { AnnouncementsBuilder.build() }
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureRootNavigationTitle()
        tableView.backgroundColor = TMETheme.Colors.groupedBackground
        tableView.separatorColor = TMETheme.TableView.separatorColor
        tableView.separatorInset = TMETheme.TableView.separatorInset
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    /// Без крупного заголовка и с уменьшаемым шрифтом — строка «Telegram Media Extension» помещается на узких экранах.
    private func configureRootNavigationTitle() {
        navigationItem.largeTitleDisplayMode = .never
        let label = UILabel()
        label.text = "Telegram Media Extension"
        label.font = TMETheme.Fonts.titleSemibold(16)
        label.textColor = .label
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.45
        label.numberOfLines = 1
        label.baselineAdjustment = .alignCenters
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        navigationItem.titleView = label
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = rows[indexPath.row]
        
        var config = cell.defaultContentConfiguration()
        config.text = row.title
        config.secondaryText = row.subtitle
        config.textProperties.font = TMETheme.Fonts.titleSemibold(17)
        config.secondaryTextProperties.color = TMETheme.Colors.secondaryText
        cell.contentConfiguration = config
        
        cell.accessoryType = .disclosureIndicator
        cell.backgroundConfiguration = UIBackgroundConfiguration.listGroupedCell()
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        navigationController?.pushViewController(rows[indexPath.row].build(), animated: false)
    }
}

