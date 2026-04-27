import Foundation

struct CommunityChat: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    /// JPEG в каталоге `CommunityStore.communityAvatarsDirectoryURL`.
    var avatarFileName: String?
    /// Привязка к произведению из внешней базы (только TMDB, например `tmdb-movie-123` / `tmdb-tv-456`).
    /// Если `nil` — сообщество «не тематическое», антиспойлеры к нему не применяются.
    var catalogSourceID: String?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        avatarFileName: String? = nil,
        catalogSourceID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.avatarFileName = avatarFileName
        self.catalogSourceID = catalogSourceID
    }
}

enum CommunityMessageKind: String, Codable {
    case post
    case announcement
}

enum CommunitySpoilerTagKind: String, Codable, Equatable {
    case filmTimecode
    case seriesEpisode
}

/// Привязка поста к произведению + “граница спойлера” (таймкод / сезон‑серия).
struct CommunitySpoilerTag: Codable, Equatable {
    /// Внешний ID произведения (только TMDB): `tmdb-movie-123` / `tmdb-tv-456`.
    var catalogSourceID: String
    /// Название для отображения в UI.
    var mediaTitle: String
    var kind: CommunitySpoilerTagKind

    /// Для сериала.
    var season: Int?
    var episode: Int?

    /// Для фильма: минуты от начала (например 45 == 00:45).
    var timeMinutes: Int?

    /// Хештег, который добавляем в текст поста.
    var hashtag: String
}

struct CommunityAnnouncement: Codable, Equatable {
    var title: String
    var date: Date
    var details: String?
    /// JPEG-изображение (баннер/постер) в каталоге `CommunityStore.announcementImagesDirectoryURL`.
    var imageFileName: String?
    /// Внешняя ссылка (опционально).
    var linkURL: String?
    /// Точка на карте (опционально).
    var location: CommunityLocation?
}

struct CommunityLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var title: String?
}

struct CommunityComment: Identifiable, Codable, Equatable {
    var id: UUID
    var messageId: UUID
    /// `nil` — комментарий к посту; иначе ответы в отдельном треде под этим комментарием.
    var threadParentCommentId: UUID?
    var text: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        messageId: UUID,
        threadParentCommentId: UUID? = nil,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messageId = messageId
        self.threadParentCommentId = threadParentCommentId
        self.text = text
        self.createdAt = createdAt
    }
}

struct CommunityMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var communityId: UUID
    var kind: CommunityMessageKind

    /// Для обоих форматов — основной текст.
    var text: String

    /// Для анонса — структурированная часть.
    var announcement: CommunityAnnouncement?

    /// Для поста — привязки к произведениям и “границы спойлера”.
    /// До 5 тегов.
    var spoilerTags: [CommunitySpoilerTag]

    var createdAt: Date

    init(
        id: UUID = UUID(),
        communityId: UUID,
        kind: CommunityMessageKind,
        text: String,
        announcement: CommunityAnnouncement? = nil,
        spoilerTags: [CommunitySpoilerTag] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.communityId = communityId
        self.kind = kind
        self.text = text
        self.announcement = announcement
        self.spoilerTags = spoilerTags
        self.createdAt = createdAt
    }
}

struct SavedAnnouncement: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceCommunityId: UUID?
    var sourceMessageId: UUID?

    var title: String
    var date: Date
    var details: String?
    var imageFileName: String?
    var linkURL: String?
    var location: CommunityLocation?

    var createdAt: Date

    init(
        id: UUID = UUID(),
        sourceCommunityId: UUID?,
        sourceMessageId: UUID?,
        title: String,
        date: Date,
        details: String? = nil,
        imageFileName: String? = nil,
        linkURL: String? = nil,
        location: CommunityLocation? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceCommunityId = sourceCommunityId
        self.sourceMessageId = sourceMessageId
        self.title = title
        self.date = date
        self.details = details
        self.imageFileName = imageFileName
        self.linkURL = linkURL
        self.location = location
        self.createdAt = createdAt
    }
}
