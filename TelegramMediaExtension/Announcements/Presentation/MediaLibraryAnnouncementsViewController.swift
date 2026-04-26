import UIKit

/// Раздел «Анонсы» внутри медиатеки: шапка и поиск как у списка каталога.
final class MediaLibraryAnnouncementsViewController: AnnouncementsChromeListTableViewController {
    init() {
        super.init(
            listTitle: "Анонсы",
            searchPlaceholder: "Поиск по анонсам",
            searchScope: .titleDetailsLink
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
