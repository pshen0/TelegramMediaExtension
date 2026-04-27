import Foundation

protocol NewAnnouncementBusinessLogic: AnyObject {
    func viewDidLoad(_ request: NewAnnouncementModel.ViewDidLoad.Request)
    func updateTitle(_ request: NewAnnouncementModel.UpdateTitle.Request)
    func updateDetails(_ request: NewAnnouncementModel.UpdateDetails.Request)
    func updateLink(_ request: NewAnnouncementModel.UpdateLink.Request)
    func setDate(_ request: NewAnnouncementModel.SetDate.Request)
    func setLocation(_ request: NewAnnouncementModel.SetLocation.Request)
    func savePickedImage(_ request: NewAnnouncementModel.SavePickedImage.Request)
    func submit(_ request: NewAnnouncementModel.Submit.Request)
}

protocol NewAnnouncementRoutingLogic: AnyObject {
    func closeAfterCreate()
    func closeAfterEdit()
}

final class NewAnnouncementInteractor: NewAnnouncementBusinessLogic {

    private let presenter: NewAnnouncementPresentationLogic
    private let store = CommunityStore.shared
    private let mode: NewAnnouncementModel.Mode

    weak var router: NewAnnouncementRoutingLogic?

    var isEditingSavedAnnouncement: Bool {
        if case .editSaved = mode { return true }
        return false
    }

    private(set) var titleText: String = ""
    private(set) var date: Date = Date().addingTimeInterval(60 * 60 * 24)
    private(set) var detailsText: String = ""
    private(set) var linkText: String = ""
    private(set) var pickedLocation: CommunityLocation?
    private(set) var imageFileName: String?

    init(presenter: NewAnnouncementPresentationLogic, mode: NewAnnouncementModel.Mode) {
        self.presenter = presenter
        self.mode = mode
    }

    func viewDidLoad(_ request: NewAnnouncementModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
        if case .editSaved(let id) = mode, let a = store.savedAnnouncements.first(where: { $0.id == id }) {
            titleText = a.title
            date = a.date
            detailsText = a.details ?? ""
            linkText = a.linkURL ?? ""
            pickedLocation = a.location
            imageFileName = a.imageFileName
        }
        presenter.presentChrome(for: mode)
        presenter.notifyFormDidChange()
    }

    func updateTitle(_ request: NewAnnouncementModel.UpdateTitle.Request) {
        titleText = request.title
    }

    func updateDetails(_ request: NewAnnouncementModel.UpdateDetails.Request) {
        detailsText = request.details
    }

    func updateLink(_ request: NewAnnouncementModel.UpdateLink.Request) {
        linkText = request.link
    }

    func setDate(_ request: NewAnnouncementModel.SetDate.Request) {
        date = request.date
        presenter.notifyFormDidChange()
    }

    func setLocation(_ request: NewAnnouncementModel.SetLocation.Request) {
        pickedLocation = request.location
        presenter.notifyFormDidChange()
    }

    func savePickedImage(_ request: NewAnnouncementModel.SavePickedImage.Request) {
        do {
            imageFileName = try store.saveAnnouncementImageJPEG(request.jpegData)
            presenter.notifyFormDidChange()
        } catch {}
    }

    func submit(_ request: NewAnnouncementModel.Submit.Request) {
        let t = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            presenter.presentValidationMissingTitle()
            return
        }
        let link = linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : linkText

        switch mode {
        case .community(let communityId):
            store.addAnnouncement(
                communityId: communityId,
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
            router?.closeAfterCreate()
        case .personal:
            store.addPersonalAnnouncement(
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
            router?.closeAfterCreate()
        case .editSaved(let id):
            store.updateSavedAnnouncement(
                id: id,
                title: t,
                date: date,
                details: detailsText,
                imageFileName: imageFileName,
                linkURL: link,
                location: pickedLocation
            )
            router?.closeAfterEdit()
        }
    }
}
