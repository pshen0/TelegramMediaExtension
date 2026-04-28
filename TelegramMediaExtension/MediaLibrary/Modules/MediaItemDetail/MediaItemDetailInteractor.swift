import Foundation

protocol MediaItemDetailBusinessLogic: AnyObject {
    func build(_ request: MediaItemDetailModel.Build.Request)
    func viewDidLoad(_ request: MediaItemDetailModel.ViewDidLoad.Request)
    func viewWillAppear(_ request: MediaItemDetailModel.ViewWillAppear.Request)
    func updateStatus(_ request: MediaItemDetailModel.UpdateStatus.Request)
    func toggleFavorite(_ request: MediaItemDetailModel.ToggleFavorite.Request)
    func share(_ request: MediaItemDetailModel.Share.Request)
    func exportJSON(_ request: MediaItemDetailModel.ExportJSON.Request)
    func delete(_ request: MediaItemDetailModel.Delete.Request)
    func edit(_ request: MediaItemDetailModel.Edit.Request)
}

protocol MediaItemDetailRoutingLogic: AnyObject {
    func routeToEdit(item: MediaItem)
    func routeToShare(text: String)
    func routeToExport(url: URL)
    func routeBackToMediaLibraryList()
    func routeToError(title: String, message: String)
}

final class MediaItemDetailInteractor: MediaItemDetailBusinessLogic {
    private let presenter: MediaItemDetailPresentationLogic
    private let store = MediaLibraryStore.shared

    weak var router: MediaItemDetailRoutingLogic?

    private var item: MediaItem?

    init(presenter: MediaItemDetailPresentationLogic) {
        self.presenter = presenter
    }

    func build(_ request: MediaItemDetailModel.Build.Request) {
        item = request.item
    }

    func viewDidLoad(_ request: MediaItemDetailModel.ViewDidLoad.Request) {
        reloadFromStoreAndPresent()
    }

    func viewWillAppear(_ request: MediaItemDetailModel.ViewWillAppear.Request) {
        reloadFromStoreAndPresent()
    }

    func updateStatus(_ request: MediaItemDetailModel.UpdateStatus.Request) {
        guard var item else { return }
        guard request.index >= 0, request.index < MediaWatchStatus.allCases.count else { return }
        item.status = MediaWatchStatus.allCases[request.index]
        store.upsert(item)
        self.item = item
        reloadFromStoreAndPresent()
    }

    func toggleFavorite(_ request: MediaItemDetailModel.ToggleFavorite.Request) {
        guard var item else { return }
        item.isFavorite.toggle()
        store.upsert(item)
        self.item = item
        reloadFromStoreAndPresent()
    }

    func share(_ request: MediaItemDetailModel.Share.Request) {
        guard let item else { return }
        let text = [item.title, item.synopsis].compactMap { $0 }.joined(separator: "\n\n")
        router?.routeToShare(text: text)
    }

    func exportJSON(_ request: MediaItemDetailModel.ExportJSON.Request) {
        reloadFromStore()
        guard let item else { return }

        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(item)
            let safeBase = item.title
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let name = String(safeBase.prefix(72))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("media_\(name).json")
            try data.write(to: url, options: [.atomic])
            router?.routeToExport(url: url)
        } catch {
            router?.routeToError(title: "Не удалось сформировать JSON", message: error.localizedDescription)
        }
    }

    func delete(_ request: MediaItemDetailModel.Delete.Request) {
        guard let item else { return }
        store.delete(id: item.id)
        router?.routeBackToMediaLibraryList()
    }

    func edit(_ request: MediaItemDetailModel.Edit.Request) {
        guard let item else { return }
        router?.routeToEdit(item: item)
    }

    private func reloadFromStore() {
        guard let item else { return }
        if let fresh = store.item(id: item.id) {
            self.item = fresh
        }
    }

    private func reloadFromStoreAndPresent() {
        reloadFromStore()
        guard let item else { return }
        presenter.presentContent(makeContentResponse(item: item))
    }

    private func makeContentResponse(item: MediaItem) -> MediaItemDetailModel.Content.Response {
        var meta: [String] = [item.kind.title]
        if let y = item.year { meta.append(String(y)) }
        if let g = item.genre, !g.isEmpty { meta.append(g) }
        if let r = item.rating { meta.append(String(format: "★ %.1f/5", r)) }

        let synopsisText: String
        let synopsisIsPlaceholder: Bool
        if let s = item.synopsis, !s.isEmpty {
            synopsisText = s
            synopsisIsPlaceholder = false
        } else {
            synopsisText = "Описание не указано."
            synopsisIsPlaceholder = true
        }

        let statusIndex = MediaWatchStatus.allCases.firstIndex(of: item.status) ?? 0

        let progressText: String = {
            var parts: [String] = []
            if item.kind == .series, let s = item.progress.season, s > 0 {
                parts.append("Сезон \(s)")
            }
            if let p = item.progress.displayString(kind: item.kind) {
                parts.append(p)
            }
            return parts.isEmpty ? "Прогресс не задан" : parts.joined(separator: " · ")
        }()

        let notesText = item.notes.isEmpty ? "—" : item.notes

        let tagsText: String
        let tagsArePlaceholder: Bool
        if item.hashtags.isEmpty {
            tagsText = "—"
            tagsArePlaceholder = true
        } else {
            tagsText = item.hashtags.map { "#\($0)" }.joined(separator: "  ")
            tagsArePlaceholder = false
        }

        return .init(
            item: item,
            title: item.title,
            metaText: meta.joined(separator: " · "),
            synopsisText: synopsisText,
            synopsisIsPlaceholder: synopsisIsPlaceholder,
            statusIndex: statusIndex,
            progressText: progressText,
            notesText: notesText,
            tagsText: tagsText,
            tagsArePlaceholder: tagsArePlaceholder
        )
    }
}

