import Foundation

struct CommunityChat: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum CommunityMessageKind: String, Codable {
    case post
    case announcement
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
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), messageId: UUID, text: String, createdAt: Date = Date()) {
        self.id = id
        self.messageId = messageId
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

    var createdAt: Date

    init(
        id: UUID = UUID(),
        communityId: UUID,
        kind: CommunityMessageKind,
        text: String,
        announcement: CommunityAnnouncement? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.communityId = communityId
        self.kind = kind
        self.text = text
        self.announcement = announcement
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
