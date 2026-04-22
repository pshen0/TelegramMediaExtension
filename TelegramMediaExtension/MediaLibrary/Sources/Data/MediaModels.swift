import Foundation

enum MediaItemKind: String, Codable, CaseIterable {
    case film
    case series
    case book
    case musicAlbum

    var title: String {
        switch self {
        case .film: return "Фильм"
        case .series: return "Сериал"
        case .book: return "Книга"
        case .musicAlbum: return "Музыкальный альбом"
        }
    }
}

enum MediaWatchStatus: String, Codable, CaseIterable {
    case planned
    case inProgress
    case completed
    case onHold

    var title: String {
        switch self {
        case .planned: return "В планах"
        case .inProgress: return "В процессе"
        case .completed: return "Завершено"
        case .onHold: return "Пауза"
        }
    }

    /// Короткие подписи для сегментов в стиле папок в чатах (влезают в `UISegmentedControl`).
    var folderTabTitle: String {
        switch self {
        case .planned: return "В планах"
        case .inProgress: return "В процессе"
        case .completed: return "Завершено"
        case .onHold: return "Пауза"
        }
    }
}

struct MediaProgress: Codable, Equatable {
    var current: Int?
    var total: Int?
    /// Для сериалов: номер сезона (опционально).
    var season: Int?

    init(current: Int? = nil, total: Int? = nil, season: Int? = nil) {
        self.current = current
        self.total = total
        self.season = season
    }

    /// «Текущий» не больше «Всего», если задано и то и другое.
    mutating func clampCurrentToTotal() {
        guard let t = total, t >= 0 else { return }
        if let c = current {
            current = min(max(0, c), t)
        }
    }

    /// Оба значения заданы и «всего» меньше «текущего» — сохранение формы блокируем.
    var hasTotalLessThanCurrent: Bool {
        guard let t = total, let c = current else { return false }
        return t < c
    }

    func displayString(kind: MediaItemKind) -> String? {
        guard let current else { return nil }
        let unit: String
        switch kind {
        case .film:
            unit = "мин"
        case .series:
            unit = "эп."
        case .book:
            unit = "гл."
        case .musicAlbum:
            unit = "тр."
        }
        var prefix = ""
        if kind == .series, let season, season > 0 {
            prefix = "С\(season) · "
        }
        if let total, total > 0 {
            return prefix + "\(current)/\(total) \(unit)"
        } else {
            return prefix + "\(current) \(unit)"
        }
    }
}

struct MediaItem: Identifiable, Equatable {
    var id: UUID
    var kind: MediaItemKind
    var title: String
    var status: MediaWatchStatus
    var progress: MediaProgress
    var notes: String
    var hashtags: [String]
    var isFavorite: Bool
    var year: Int?
    var genre: String?
    /// 0…5 (условные «звёзды»), опционально.
    var rating: Double?
    var synopsis: String?
    /// Имя файла обложки в каталоге `MediaLibraryStore.coversDirectory` (JPEG).
    var coverFileName: String?
    /// Идентификатор во внешнем каталоге, если объект добавлен из поиска.
    var catalogSourceID: String?
    /// `false` — запись из каталога; `true` — создана вручную.
    var isManuallyCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: MediaItemKind,
        title: String,
        status: MediaWatchStatus = .planned,
        progress: MediaProgress = MediaProgress(),
        notes: String = "",
        hashtags: [String] = [],
        isFavorite: Bool = false,
        year: Int? = nil,
        genre: String? = nil,
        rating: Double? = nil,
        synopsis: String? = nil,
        coverFileName: String? = nil,
        catalogSourceID: String? = nil,
        isManuallyCreated: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.status = status
        self.progress = progress
        self.notes = notes
        self.hashtags = hashtags
        self.isFavorite = isFavorite
        self.year = year
        self.genre = genre
        self.rating = rating
        self.synopsis = synopsis
        self.coverFileName = coverFileName
        self.catalogSourceID = catalogSourceID
        self.isManuallyCreated = isManuallyCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension MediaItem: Codable {
    private enum CK: String, CodingKey {
        case id, kind, title, status, progress, notes, hashtags
        case isFavorite
        case year, genre, rating, synopsis, coverFileName, catalogSourceID, isManuallyCreated
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CK.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(MediaItemKind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        status = try c.decode(MediaWatchStatus.self, forKey: .status)
        progress = try c.decodeIfPresent(MediaProgress.self, forKey: .progress) ?? MediaProgress()
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        hashtags = try c.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        genre = try c.decodeIfPresent(String.self, forKey: .genre)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        synopsis = try c.decodeIfPresent(String.self, forKey: .synopsis)
        coverFileName = try c.decodeIfPresent(String.self, forKey: .coverFileName)
        catalogSourceID = try c.decodeIfPresent(String.self, forKey: .catalogSourceID)
        isManuallyCreated = try c.decodeIfPresent(Bool.self, forKey: .isManuallyCreated) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CK.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(title, forKey: .title)
        try c.encode(status, forKey: .status)
        try c.encode(progress, forKey: .progress)
        try c.encode(notes, forKey: .notes)
        try c.encode(hashtags, forKey: .hashtags)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encodeIfPresent(year, forKey: .year)
        try c.encodeIfPresent(genre, forKey: .genre)
        try c.encodeIfPresent(rating, forKey: .rating)
        try c.encodeIfPresent(synopsis, forKey: .synopsis)
        try c.encodeIfPresent(coverFileName, forKey: .coverFileName)
        try c.encodeIfPresent(catalogSourceID, forKey: .catalogSourceID)
        try c.encode(isManuallyCreated, forKey: .isManuallyCreated)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

enum MediaHashtag {
    static func normalize(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let noHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let cleaned = noHash
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return cleaned.isEmpty ? nil : cleaned
    }

    static func parseList(_ raw: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;")
        return raw
            .components(separatedBy: separators)
            .compactMap(normalize)
            .uniquedPreservingOrder()
    }
}

private extension Array where Element: Hashable {
    func uniquedPreservingOrder() -> [Element] {
        var seen = Set<Element>()
        var result: [Element] = []
        result.reserveCapacity(count)
        for x in self where !seen.contains(x) {
            seen.insert(x)
            result.append(x)
        }
        return result
    }
}
