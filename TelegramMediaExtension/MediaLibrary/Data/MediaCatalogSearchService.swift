import Foundation

struct MediaCatalogCandidate: Hashable, Identifiable {
    let id: String
    let kind: MediaItemKind
    let title: String
    let year: Int?
    let genre: String?
    let rating: Double?
    let synopsis: String

    func makeMediaItem(detail: TMDBClient.DetailMetadata? = nil) -> MediaItem {
        let mergedSyn: String = {
            if let s = detail?.synopsis?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return s
            }
            return synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        var progress = MediaProgress()
        if kind == .series {
            if let t = detail?.totalEpisodes, t > 0 {
                progress.total = t
            }
            if detail?.numberOfSeasons != nil {
                progress.season = 1
            }
        }
        if kind == .film, let run = detail?.runtimeMinutes, run > 0 {
            progress.current = 0
            progress.total = run
        }
        let synOpt = mergedSyn.isEmpty ? nil : mergedSyn
        return MediaItem(
            kind: kind,
            title: title,
            status: .planned,
            progress: progress,
            notes: "",
            hashtags: [],
            year: detail?.year ?? year,
            genre: detail?.genre ?? genre,
            rating: detail?.rating ?? rating,
            synopsis: synOpt,
            coverFileName: nil,
            catalogSourceID: id,
            isManuallyCreated: false
        )
    }
}

enum MediaCatalogSearchService {
    // Поиск: при `TMDBAPIKey` в Info.plist — TMDB
    static func search(query: String) async -> [MediaCatalogCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        try? await Task.sleep(nanoseconds: 220_000_000)

        var remote: [MediaCatalogCandidate] = []
        if TMDBClient.isConfigured {
            do {
                remote = try await TMDBClient.searchMulti(query: query)
            } catch {
                remote = []
            }
        }

        let local = mockCatalog.filter { cand in
            cand.title.lowercased().contains(q)
                || (cand.genre?.lowercased().contains(q) ?? false)
                || cand.synopsis.lowercased().contains(q)
        }

        var seen = Set<String>()
        var merged: [MediaCatalogCandidate] = []
        for c in remote + local {
            if seen.insert(c.id).inserted {
                merged.append(c)
            }
        }
        return merged
    }

    private static let mockCatalog: [MediaCatalogCandidate] = [
        MediaCatalogCandidate(
            id: "tmdb-inception",
            kind: .film,
            title: "Начало",
            year: 2010,
            genre: "Sci-Fi",
            rating: 4.6,
            synopsis: "Вор проникает в сны других людей, чтобы украсть секреты из подсознания."
        ),
        MediaCatalogCandidate(
            id: "tmdb-dune",
            kind: .film,
            title: "Дюна",
            year: 2021,
            genre: "Sci-Fi",
            rating: 4.4,
            synopsis: "Дом Атрейдесов получает контроль над планетой Арракис."
        ),
        MediaCatalogCandidate(
            id: "tmdb-breaking-bad",
            kind: .series,
            title: "Во все тяжкие",
            year: 2008,
            genre: "Драма",
            rating: 4.9,
            synopsis: "Учитель химии начинает производить метамфетамин после диагноза рака."
        ),
        MediaCatalogCandidate(
            id: "tmdb-the-wire",
            kind: .series,
            title: "Прослушка",
            year: 2002,
            genre: "Криминал",
            rating: 4.8,
            synopsis: "Балтимор глазами полиции, банд и политиков."
        ),
        MediaCatalogCandidate(
            id: "openlibrary-1984",
            kind: .book,
            title: "1984",
            year: 1949,
            genre: "Антиутопия",
            rating: 4.7,
            synopsis: "Тоталитарное общество тотального надзора."
        ),
        MediaCatalogCandidate(
            id: "openlibrary-hobbit",
            kind: .book,
            title: "Хоббит",
            year: 1937,
            genre: "Фэнтези",
            rating: 4.5,
            synopsis: "Путешествие Бильбо Бэггинса к Одинокой горе."
        ),
        MediaCatalogCandidate(
            id: "mb-random-access",
            kind: .musicAlbum,
            title: "Random Access Memories",
            year: 2013,
            genre: "Electronic",
            rating: 4.6,
            synopsis: "Daft Punk — четвёртый студийный альбом."
        )
    ]
}
