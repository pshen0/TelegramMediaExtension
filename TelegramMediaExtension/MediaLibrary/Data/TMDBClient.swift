import Foundation

enum TMDBClient {
    private static let host = "api.themoviedb.org"

    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static var isConfigured: Bool { !apiKey.isEmpty }

    private static func isBearerToken(_ value: String) -> Bool {
        value.hasPrefix("eyJ") && value.split(separator: ".").count == 3
    }

    private static func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if isBearerToken(apiKey) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private static func dataAuthorized(from url: URL) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: authorizedRequest(url: url))
    }

    struct DetailMetadata: Sendable {
        var year: Int?
        var genre: String?
        var rating: Double?
        var synopsis: String?
        var totalEpisodes: Int?
        var numberOfSeasons: Int?
        var runtimeMinutes: Int?
    }

    static func searchMulti(query: String) async throws -> [MediaCatalogCandidate] {
        guard isConfigured else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }

        var comp = URLComponents()
        comp.scheme = "https"
        comp.host = host
        comp.path = "/3/search/multi"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "language", value: "ru-RU"),
            URLQueryItem(name: "query", value: q),
            URLQueryItem(name: "page", value: "1")
        ]
        if !isBearerToken(apiKey) {
            queryItems.insert(URLQueryItem(name: "api_key", value: apiKey), at: 0)
        }
        comp.queryItems = queryItems
        guard let url = comp.url else { return [] }

        let (data, response) = try await dataAuthorized(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            return []
        }

        let decoded = try JSONDecoder().decode(TMDBMultiSearchResponse.self, from: data)
        return decoded.results.compactMap(mapSearchResult)
    }

    static func fetchDetail(candidateId: String) async -> DetailMetadata? {
        guard isConfigured else { return nil }
        guard let ref = parseCatalogId(candidateId) else { return nil }

        do {
            switch ref {
            case .movie(let id):
                return try await fetchMovieDetail(id: id)
            case .tv(let id):
                return try await fetchTVDetail(id: id)
            }
        } catch {
            return nil
        }
    }

    private static func fetchMovieDetail(id: Int) async throws -> DetailMetadata {
        let url = try makeURL(path: "/3/movie/\(id)", extra: [
            URLQueryItem(name: "language", value: "ru-RU")
        ])
        let (data, response) = try await dataAuthorized(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let m = try JSONDecoder().decode(TMDBMovieDetail.self, from: data)
        let year = m.release_date.flatMap { Int(String($0.prefix(4))) }
        let genres = m.genres.prefix(2).map(\.name).joined(separator: ", ")
        let rating = m.vote_average.map { min(5, max(0, $0 / 2.0)) }
        return DetailMetadata(
            year: year,
            genre: genres.isEmpty ? nil : genres,
            rating: rating,
            synopsis: m.overview?.isEmpty == false ? m.overview : nil,
            totalEpisodes: nil,
            numberOfSeasons: nil,
            runtimeMinutes: m.runtime
        )
    }

    private static func fetchTVDetail(id: Int) async throws -> DetailMetadata {
        let url = try makeURL(path: "/3/tv/\(id)", extra: [
            URLQueryItem(name: "language", value: "ru-RU")
        ])
        let (data, response) = try await dataAuthorized(from: url)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let t = try JSONDecoder().decode(TMDBTVDetail.self, from: data)
        let year = t.first_air_date.flatMap { Int(String($0.prefix(4))) }
        let genres = t.genres.prefix(2).map(\.name).joined(separator: ", ")
        let rating = t.vote_average.map { min(5, max(0, $0 / 2.0)) }
        return DetailMetadata(
            year: year,
            genre: genres.isEmpty ? nil : genres,
            rating: rating,
            synopsis: t.overview?.isEmpty == false ? t.overview : nil,
            totalEpisodes: t.number_of_episodes,
            numberOfSeasons: t.number_of_seasons,
            runtimeMinutes: nil
        )
    }

    private static func makeURL(path: String, extra: [URLQueryItem]) throws -> URL {
        var comp = URLComponents()
        comp.scheme = "https"
        comp.host = host
        comp.path = path
        var items = extra
        if !isBearerToken(apiKey) {
            items.insert(URLQueryItem(name: "api_key", value: apiKey), at: 0)
        }
        comp.queryItems = items
        guard let url = comp.url else { throw URLError(.badURL) }
        return url
    }

    private enum CatalogRef {
        case movie(Int)
        case tv(Int)
    }

    private static func parseCatalogId(_ id: String) -> CatalogRef? {
        let parts = id.split(separator: "-")
        guard parts.count >= 3, parts[0] == "tmdb" else { return nil }
        guard let num = Int(parts[2]) else { return nil }
        switch parts[1] {
        case "movie": return .movie(num)
        case "tv": return .tv(num)
        default: return nil
        }
    }

    private static func mapSearchResult(_ r: TMDBMultiResult) -> MediaCatalogCandidate? {
        let type = r.media_type ?? ""
        switch type {
        case "movie":
            let title = r.title ?? r.original_title ?? ""
            guard !title.isEmpty else { return nil }
            let year = r.release_date.flatMap { Int(String($0.prefix(4))) }
            let syn = r.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rating = r.vote_average.map { min(5, max(0, $0 / 2.0)) }
            return MediaCatalogCandidate(
                id: "tmdb-movie-\(r.id)",
                kind: .film,
                title: title,
                year: year,
                genre: nil,
                rating: rating,
                synopsis: syn.isEmpty ? " " : syn
            )
        case "tv":
            let title = r.name ?? r.original_name ?? ""
            guard !title.isEmpty else { return nil }
            let year = r.first_air_date.flatMap { Int(String($0.prefix(4))) }
            let syn = r.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let rating = r.vote_average.map { min(5, max(0, $0 / 2.0)) }
            return MediaCatalogCandidate(
                id: "tmdb-tv-\(r.id)",
                kind: .series,
                title: title,
                year: year,
                genre: nil,
                rating: rating,
                synopsis: syn.isEmpty ? " " : syn
            )
        default:
            return nil
        }
    }
}

// MARK: - TMDB JSON

private struct TMDBMultiSearchResponse: Decodable {
    let results: [TMDBMultiResult]
}

private struct TMDBMultiResult: Decodable {
    let id: Int
    let media_type: String?
    let title: String?
    let original_title: String?
    let name: String?
    let original_name: String?
    let release_date: String?
    let first_air_date: String?
    let overview: String?
    let vote_average: Double?
}

private struct TMDBMovieDetail: Decodable {
    let release_date: String?
    let runtime: Int?
    let overview: String?
    let vote_average: Double?
    let genres: [TMDBGenre]
}

private struct TMDBTVDetail: Decodable {
    let first_air_date: String?
    let number_of_episodes: Int?
    let number_of_seasons: Int?
    let overview: String?
    let vote_average: Double?
    let genres: [TMDBGenre]
}

private struct TMDBGenre: Decodable {
    let name: String
}
