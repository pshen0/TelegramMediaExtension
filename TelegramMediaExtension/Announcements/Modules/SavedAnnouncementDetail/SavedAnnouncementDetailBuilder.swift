import UIKit

enum SavedAnnouncementDetailBuilder {

    static func build(announcement: SavedAnnouncement) -> SavedAnnouncementDetailViewController {
        let presenter = SavedAnnouncementDetailPresenter()
        let interactor = SavedAnnouncementDetailInteractor(presenter: presenter, announcementId: announcement.id)
        let view = SavedAnnouncementDetailViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}
