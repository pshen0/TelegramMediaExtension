import Foundation

protocol MediaCatalogSearchBusinessLogic: AnyObject {
    func viewDidLoad(_ request: MediaCatalogSearchModel.ViewDidLoad.Request)
    func queryChanged(_ request: MediaCatalogSearchModel.QueryChanged.Request)
}

final class MediaCatalogSearchInteractor: MediaCatalogSearchBusinessLogic {
    private let presenter: MediaCatalogSearchPresentationLogic
    private var searchTask: Task<Void, Never>?

    init(presenter: MediaCatalogSearchPresentationLogic) {
        self.presenter = presenter
    }

    func viewDidLoad(_ request: MediaCatalogSearchModel.ViewDidLoad.Request) {
        presenter.presentList(.init(rows: []))
    }

    func queryChanged(_ request: MediaCatalogSearchModel.QueryChanged.Request) {
        searchTask?.cancel()
        let q = request.query
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let list = await MediaCatalogSearchService.search(query: q)
            guard !Task.isCancelled else { return }
            let rows: [MediaCatalogSearchModel.List.Row] = list.map { c in
                let secondary = [c.kind.title, c.year.map(String.init), c.genre]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                return .init(candidate: c, secondaryText: secondary)
            }
            await MainActor.run {
                self?.presenter.presentList(.init(rows: rows))
            }
        }
    }
}

