import Foundation

protocol AnnouncementsChromeListDisplayLogic: AnyObject {
    func displayAnnouncements(_ viewModel: AnnouncementsChromeListModel.AnnouncementsChanged.ViewModel)
}

protocol AnnouncementsChromeListPresentationLogic: AnyObject {
    func presentAnnouncements(_ response: AnnouncementsChromeListModel.AnnouncementsChanged.Response)
}

final class AnnouncementsChromeListPresenter: AnnouncementsChromeListPresentationLogic {

    weak var view: AnnouncementsChromeListDisplayLogic?

    func presentAnnouncements(_ response: AnnouncementsChromeListModel.AnnouncementsChanged.Response) {
        let rows = response.announcements.map { a in
            AnnouncementsChromeListModel.AnnouncementsChanged.Row(
                id: a.id,
                title: a.title,
                subtitle: Self.formatDate(a.date)
            )
        }
        view?.displayAnnouncements(AnnouncementsChromeListModel.AnnouncementsChanged.ViewModel(rows: rows))
    }

    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
