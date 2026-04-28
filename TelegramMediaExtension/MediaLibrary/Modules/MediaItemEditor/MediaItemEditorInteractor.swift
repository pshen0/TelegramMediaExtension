import Foundation

protocol MediaItemEditorBusinessLogic: AnyObject {
    func build(_ request: MediaItemEditorModel.Build.Request)
    func viewDidLoad(_ request: MediaItemEditorModel.ViewDidLoad.Request)
    func updateField(_ request: MediaItemEditorModel.UpdateField.Request)
    func updateKind(_ request: MediaItemEditorModel.UpdateKind.Request)
    func updateStatus(_ request: MediaItemEditorModel.UpdateStatus.Request)
    func saveTapped(_ request: MediaItemEditorModel.SaveTapped.Request)
    func deleteConfirmed(_ request: MediaItemEditorModel.DeleteConfirmed.Request)
}

protocol MediaItemEditorRoutingLogic: AnyObject {
    func routeOnSave(item: MediaItem)
    func routeBackAfterDelete()
}

final class MediaItemEditorInteractor: MediaItemEditorBusinessLogic {
    private let presenter: MediaItemEditorPresentationLogic
    private let store = MediaLibraryStore.shared
    weak var router: MediaItemEditorRoutingLogic?

    private var mode: MediaItemEditorViewController.Mode?
    private var item: MediaItem?

    init(presenter: MediaItemEditorPresentationLogic) {
        self.presenter = presenter
    }

    func build(_ request: MediaItemEditorModel.Build.Request) {
        mode = request.mode
        switch request.mode {
        case .create:
            item = MediaItem(kind: .film, title: "", isManuallyCreated: true)
        case .createPrefilled(let draft):
            item = draft
        case .edit(let existing):
            item = existing
        }
    }

    func viewDidLoad(_ request: MediaItemEditorModel.ViewDidLoad.Request) {
        pushContent()
    }

    func updateField(_ request: MediaItemEditorModel.UpdateField.Request) {
        guard var item else { return }
        switch request.field {
        case .title(let v): item.title = v
        case .year(let v): item.year = v
        case .genre(let v): item.genre = v
        case .rating(let v): item.rating = v
        case .synopsis(let v): item.synopsis = v
        case .progressSeason(let v): item.progress.season = v
        case .progressCurrent(let v): item.progress.current = v
        case .progressTotal(let v): item.progress.total = v
        case .spoilersProtectionEnabled(let v): item.spoilersProtectionEnabled = v
        case .notes(let v): item.notes = v
        case .hashtags(let v): item.hashtags = v
        case .coverFileName(let v): item.coverFileName = v
        }
        self.item = item
        pushContent()
    }

    func updateKind(_ request: MediaItemEditorModel.UpdateKind.Request) {
        guard var item else { return }
        item.kind = request.kind
        self.item = item
        pushContent()
    }

    func updateStatus(_ request: MediaItemEditorModel.UpdateStatus.Request) {
        guard var item else { return }
        item.status = request.status
        self.item = item
        pushContent()
    }

    func saveTapped(_ request: MediaItemEditorModel.SaveTapped.Request) {
        guard var item else { return }
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            presenter.presentError(title: "Введите название", message: nil)
            return
        }
        if item.progress.hasTotalLessThanCurrent {
            presenter.presentError(
                title: "Прогресс",
                message: "«Всего» не может быть меньше текущего значения. Исправьте поля и попробуйте снова."
            )
            return
        }
        item.title = title
        self.item = item
        router?.routeOnSave(item: item)
    }

    func deleteConfirmed(_ request: MediaItemEditorModel.DeleteConfirmed.Request) {
        guard let mode else { return }
        guard case .edit(let existing) = mode else { return }
        store.delete(id: existing.id)
        router?.routeBackAfterDelete()
    }

    private func pushContent() {
        guard let mode, let item else { return }
        let navTitle = mode.navigationTitle.isEmpty ? item.title : mode.navigationTitle
        let canDelete: Bool = {
            if case .edit = mode { return true }
            return false
        }()
        presenter.presentContent(.init(mode: mode, item: item, navigationTitle: navTitle, canDelete: canDelete))
    }
}

