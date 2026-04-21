import Foundation

/// Результат «внешнего» каталога (заглушка до подключения реального API).
struct MediaCatalogCandidate: Hashable, Identifiable {
    let id: String
    let kind: MediaItemKind
    let title: String
    let year: Int?
    let genre: String?
    let rating: Double?
    let synopsis: String

    func makeMediaItem() -> MediaItem {
        MediaItem(
            kind: kind,
            title: title,
            status: .planned,
            progress: MediaProgress(),
            notes: "",
            hashtags: [],
            year: year,
            genre: genre,
            rating: rating,
            synopsis: synopsis,
            coverFileName: nil,
            catalogSourceID: id,
            isManuallyCreated: false
        )
    }
}

enum MediaCatalogSearchService {
    /// Поиск по заглушечному каталогу (имитация сетевой задержки).
    static func search(query: String) async -> [MediaCatalogCandidate] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        try? await Task.sleep(nanoseconds: 350_000_000)
        return mockCatalog.filter { cand in
            cand.title.lowercased().contains(q)
                || (cand.genre?.lowercased().contains(q) ?? false)
                || cand.synopsis.lowercased().contains(q)
        }
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
