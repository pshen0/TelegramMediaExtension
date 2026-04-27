import UIKit

enum NewAnnouncementBuilder {

    static func build(communityId: UUID) -> NewAnnouncementViewController {
        build(mode: .community(communityId))
    }

    static func buildPersonal() -> NewAnnouncementViewController {
        build(mode: .personal)
    }

    static func buildEditingSavedAnnouncement(id: UUID) -> NewAnnouncementViewController {
        build(mode: .editSaved(id))
    }

    private static func build(mode: NewAnnouncementModel.Mode) -> NewAnnouncementViewController {
        let presenter = NewAnnouncementPresenter()
        let interactor = NewAnnouncementInteractor(presenter: presenter, mode: mode)
        let view = NewAnnouncementViewController(interactor: interactor)
        presenter.view = view
        interactor.router = view
        return view
    }
}
