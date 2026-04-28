import UIKit

enum AnnouncementsChromeListBuilder {

    static func myAnnouncements() -> AnnouncementsChromeListViewController {
        build(
            listTitle: "Мои анонсы",
            searchPlaceholder: "Поиск по названию",
            searchScope: .titleOnly,
            headerBannerImage: .duck2
        )
    }

    static func mediaLibraryAnnouncements() -> AnnouncementsChromeListViewController {
        build(
            listTitle: "Анонсы",
            searchPlaceholder: "Поиск по анонсам",
            searchScope: .titleDetailsLink,
            headerBannerImage: .duck1
        )
    }

    static func build(
        listTitle: String,
        searchPlaceholder: String,
        searchScope: AnnouncementsChromeListModel.SearchScope,
        headerBannerImage: MediaLibraryChromeHeaderView.BannerImage = .duck1
    ) -> AnnouncementsChromeListViewController {
        let presenter = AnnouncementsChromeListPresenter()
        let interactor = AnnouncementsChromeListInteractor(presenter: presenter, searchScope: searchScope)
        let view = AnnouncementsChromeListViewController(
            interactor: interactor,
            listTitle: listTitle,
            searchPlaceholder: searchPlaceholder,
            headerBannerImage: headerBannerImage
        )
        presenter.view = view
        interactor.router = view
        return view
    }
}
