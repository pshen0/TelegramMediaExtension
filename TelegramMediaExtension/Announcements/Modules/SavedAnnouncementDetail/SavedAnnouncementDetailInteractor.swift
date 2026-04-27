import Foundation

protocol SavedAnnouncementDetailBusinessLogic: AnyObject {
    func viewDidLoad(_ request: SavedAnnouncementDetailModel.ViewDidLoad.Request)
    func viewWillAppear(_ request: SavedAnnouncementDetailModel.ViewWillAppear.Request)
    func refreshDisplay(_ request: SavedAnnouncementDetailModel.RefreshDisplay.Request)
    func editTap(_ request: SavedAnnouncementDetailModel.EditTap.Request)
    func openLink(_ request: SavedAnnouncementDetailModel.OpenLink.Request)
}

protocol SavedAnnouncementDetailRoutingLogic: AnyObject {
    func popBecauseAnnouncementRemoved()
    func showEditSavedAnnouncement(id: UUID)
    func presentSafari(url: URL)
}

final class SavedAnnouncementDetailInteractor: SavedAnnouncementDetailBusinessLogic {

    private let presenter: SavedAnnouncementDetailPresentationLogic
    private let store = CommunityStore.shared

    /// Для синхронизации загрузки баннера с актуальной записью в `CommunityStore`.
    let announcementId: UUID

    weak var router: SavedAnnouncementDetailRoutingLogic?

    init(presenter: SavedAnnouncementDetailPresentationLogic, announcementId: UUID) {
        self.presenter = presenter
        self.announcementId = announcementId
    }

    func viewDidLoad(_ request: SavedAnnouncementDetailModel.ViewDidLoad.Request) {
        store.loadIfNeeded()
    }

    func viewWillAppear(_ request: SavedAnnouncementDetailModel.ViewWillAppear.Request) {
        guard currentAnnouncement() != nil else {
            router?.popBecauseAnnouncementRemoved()
            return
        }
    }

    func refreshDisplay(_ request: SavedAnnouncementDetailModel.RefreshDisplay.Request) {
        refreshIfPossible(heroStripVisible: request.heroStripVisible)
    }

    func editTap(_ request: SavedAnnouncementDetailModel.EditTap.Request) {
        guard let a = currentAnnouncement() else { return }
        router?.showEditSavedAnnouncement(id: a.id)
    }

    func openLink(_ request: SavedAnnouncementDetailModel.OpenLink.Request) {
        let t = request.trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let urlString =
            t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://")
            ? t
            : "https://\(t)"
        guard let url = URL(string: urlString) else { return }
        router?.presentSafari(url: url)
    }

    private func refreshIfPossible(heroStripVisible: Bool) {
        guard let a = currentAnnouncement() else { return }
        let communityName: String?
        if let cid = a.sourceCommunityId {
            communityName = store.communityTitle(id: cid)
        } else {
            communityName = nil
        }
        presenter.presentAnnouncement(
            SavedAnnouncementDetailModel.LoadAnnouncement.Response(
                announcement: a,
                heroStripVisible: heroStripVisible,
                communitySourceName: communityName
            )
        )
    }

    private func currentAnnouncement() -> SavedAnnouncement? {
        store.savedAnnouncements.first { $0.id == announcementId }
    }
}
