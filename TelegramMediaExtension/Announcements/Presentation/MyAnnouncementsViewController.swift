import UIKit

/// «Мои анонсы»: та же шапка и поиск, что в медиатеке; поиск только по названию.
final class MyAnnouncementsViewController: AnnouncementsChromeListTableViewController {
    init() {
        super.init(
            listTitle: "Мои анонсы",
            searchPlaceholder: "Поиск по названию",
            searchScope: .titleOnly
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
