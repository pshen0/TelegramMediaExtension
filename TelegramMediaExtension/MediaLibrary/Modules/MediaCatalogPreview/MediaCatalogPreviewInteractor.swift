import Foundation

protocol MediaCatalogPreviewBusinessLogic: AnyObject {
    func build(_ request: MediaCatalogPreviewModel.Build.Request)
    func loadDetailIfNeeded(_ request: MediaCatalogPreviewModel.LoadDetailIfNeeded.Request)
    func addTapped(_ request: MediaCatalogPreviewModel.AddTapped.Request)
}

protocol MediaCatalogPreviewRoutingLogic: AnyObject {
    func routeToCreatePrefilled(item: MediaItem)
}

final class MediaCatalogPreviewInteractor: MediaCatalogPreviewBusinessLogic {
    private let presenter: MediaCatalogPreviewPresentationLogic
    weak var router: MediaCatalogPreviewRoutingLogic?

    private var candidate: MediaCatalogCandidate?
    private var loadedDetail: TMDBClient.DetailMetadata?

    init(presenter: MediaCatalogPreviewPresentationLogic) {
        self.presenter = presenter
    }

    func build(_ request: MediaCatalogPreviewModel.Build.Request) {
        candidate = request.candidate
        pushContent(hintText: TMDBClient.isConfigured && request.candidate.id.hasPrefix("tmdb-")
            ? "Подтягиваем описание и число серий из каталога TMDB…"
            : nil)
    }

    func loadDetailIfNeeded(_ request: MediaCatalogPreviewModel.LoadDetailIfNeeded.Request) {
        guard TMDBClient.isConfigured, let candidate, candidate.id.hasPrefix("tmdb-") else {
            pushContent(hintText: nil)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let detail = await TMDBClient.fetchDetail(candidateId: candidate.id)
            await MainActor.run {
                self.loadedDetail = detail
                self.pushContent(hintText: nil)
            }
        }
    }

    func addTapped(_ request: MediaCatalogPreviewModel.AddTapped.Request) {
        guard let candidate else { return }
        let item = candidate.makeMediaItem(detail: loadedDetail)
        router?.routeToCreatePrefilled(item: item)
    }

    private func pushContent(hintText: String?) {
        guard let candidate else { return }
        let d = loadedDetail

        var metaParts: [String] = []
        let year = d?.year ?? candidate.year
        if let y = year { metaParts.append(String(y)) }
        let genre = d?.genre ?? candidate.genre
        if let g = genre, !g.isEmpty { metaParts.append(g) }
        let rating = d?.rating ?? candidate.rating
        if let r = rating { metaParts.append(String(format: "★ %.1f/5", r)) }
        if candidate.kind == .series {
            if let ep = d?.totalEpisodes, ep > 0 {
                metaParts.append("\(ep) эп.")
            }
            if let ss = d?.numberOfSeasons, ss > 0 {
                metaParts.append("\(ss) сез.")
            }
        }
        if candidate.kind == .film, let run = d?.runtimeMinutes, run > 0 {
            metaParts.append("\(run) мин")
        }
        let metaText = metaParts.joined(separator: " · ")

        let synopsisText: String = {
            if let s = d?.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
            let base = candidate.synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
            return base.isEmpty ? "Нет описания." : base
        }()

        presenter.presentContent(
            .init(
                title: candidate.title,
                kindTitle: candidate.kind.title,
                metaText: metaText,
                synopsisText: synopsisText,
                hintText: hintText
            )
        )
    }
}

