import Combine
import Foundation

@MainActor
final class CommunityStore: ObservableObject {
    static let shared = CommunityStore()

    @Published private(set) var communities: [CommunityChat] = []
    @Published private(set) var messages: [CommunityMessage] = []
    @Published private(set) var savedAnnouncements: [SavedAnnouncement] = []
    @Published private(set) var comments: [CommunityComment] = []

    private let fileURL: URL
    private var isLoaded = false

    private struct Persisted: Codable {
        var communities: [CommunityChat]
        var messages: [CommunityMessage]
        var savedAnnouncements: [SavedAnnouncement]
        var comments: [CommunityComment]
    }

    private init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = base.appendingPathComponent("communities_v1.json")
    }

    // MARK: - Announcement images

    static var announcementImagesDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("TelegramMediaExtension", isDirectory: true)
        return root.appendingPathComponent("CommunityAnnouncementImages", isDirectory: true)
    }

    static func announcementImageURL(fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return announcementImagesDirectoryURL.appendingPathComponent(fileName)
    }

    func saveAnnouncementImageJPEG(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: Self.announcementImagesDirectoryURL, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        try data.write(to: Self.announcementImagesDirectoryURL.appendingPathComponent(name), options: [.atomic])
        return name
    }

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        reloadFromDisk()
        if communities.isEmpty {
            seedIfEmpty()
        }
    }

    func reloadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(Persisted.self, from: data)
            communities = decoded.communities.sorted { $0.updatedAt > $1.updatedAt }
            messages = decoded.messages.sorted { $0.createdAt < $1.createdAt }
            savedAnnouncements = decoded.savedAnnouncements.sorted { $0.date < $1.date }
            comments = decoded.comments.sorted { $0.createdAt < $1.createdAt }
        } catch {
            communities = []
            messages = []
            savedAnnouncements = []
            comments = []
        }
    }

    func createCommunity(title: String) -> CommunityChat {
        loadIfNeeded()
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = CommunityChat(title: trimmed.isEmpty ? "Сообщество" : trimmed)
        communities.insert(c, at: 0)
        persist()
        return c
    }

    func upsertCommunity(_ community: CommunityChat) {
        loadIfNeeded()
        var c = community
        c.updatedAt = Date()
        if let i = communities.firstIndex(where: { $0.id == c.id }) {
            communities[i] = c
        } else {
            communities.insert(c, at: 0)
        }
        persist()
    }

    func deleteCommunity(id: UUID) {
        loadIfNeeded()
        let messageIds = messages.filter { $0.communityId == id }.map(\.id)
        communities.removeAll(where: { $0.id == id })
        messages.removeAll(where: { $0.communityId == id })
        if !messageIds.isEmpty {
            let set = Set(messageIds)
            comments.removeAll(where: { set.contains($0.messageId) })
        }
        persist()
    }

    func messages(for communityId: UUID) -> [CommunityMessage] {
        loadIfNeeded()
        return messages.filter { $0.communityId == communityId }.sorted { $0.createdAt < $1.createdAt }
    }

    func comments(for messageId: UUID) -> [CommunityComment] {
        loadIfNeeded()
        return comments.filter { $0.messageId == messageId }.sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(messageId: UUID, text: String) {
        loadIfNeeded()
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        comments.append(CommunityComment(messageId: messageId, text: t))
        persist()
    }

    func addPost(communityId: UUID, text: String) {
        loadIfNeeded()
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let m = CommunityMessage(communityId: communityId, kind: .post, text: t)
        messages.append(m)
        touchCommunity(communityId)
        persist()
    }

    func addAnnouncement(
        communityId: UUID,
        title: String,
        date: Date,
        details: String?,
        imageFileName: String? = nil,
        linkURL: String? = nil,
        location: CommunityLocation? = nil
    ) {
        loadIfNeeded()
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let a = CommunityAnnouncement(
            title: t,
            date: date,
            details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
            imageFileName: imageFileName,
            linkURL: linkURL,
            location: location
        )
        let body = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = CommunityMessage(
            communityId: communityId,
            kind: .announcement,
            text: body?.isEmpty == false ? body! : "Анонс",
            announcement: a
        )
        messages.append(m)
        touchCommunity(communityId)
        persist()
    }

    func saveAnnouncementFromMessage(_ message: CommunityMessage) {
        loadIfNeeded()
        guard message.kind == .announcement, let a = message.announcement else { return }
        if savedAnnouncements.contains(where: { $0.sourceMessageId == message.id }) {
            return
        }
        let fp = Self.announcementFingerprint(title: a.title, date: a.date, details: a.details, imageFileName: a.imageFileName, linkURL: a.linkURL, location: a.location)
        if savedAnnouncements.contains(where: { Self.savedFingerprint($0) == fp }) {
            return
        }
        savedAnnouncements.append(
            SavedAnnouncement(
                sourceCommunityId: message.communityId,
                sourceMessageId: message.id,
                title: a.title,
                date: a.date,
                details: a.details,
                imageFileName: a.imageFileName,
                linkURL: a.linkURL,
                location: a.location
            )
        )
        savedAnnouncements.sort { $0.date < $1.date }
        persist()
    }

    func deleteSavedAnnouncement(id: UUID) {
        loadIfNeeded()
        savedAnnouncements.removeAll(where: { $0.id == id })
        persist()
    }

    private static func announcementFingerprint(
        title: String,
        date: Date,
        details: String?,
        imageFileName: String?,
        linkURL: String?,
        location: CommunityLocation?
    ) -> String {
        let loc = location.map { "\($0.latitude),\($0.longitude),\($0.title ?? "")" } ?? ""
        return [title, String(date.timeIntervalSince1970), details ?? "", imageFileName ?? "", linkURL ?? "", loc].joined(separator: "\u{1e}")
    }

    private static func savedFingerprint(_ s: SavedAnnouncement) -> String {
        announcementFingerprint(title: s.title, date: s.date, details: s.details, imageFileName: s.imageFileName, linkURL: s.linkURL, location: s.location)
    }

    private func touchCommunity(_ id: UUID) {
        guard let i = communities.firstIndex(where: { $0.id == id }) else { return }
        var c = communities[i]
        c.updatedAt = Date()
        communities[i] = c
        communities.sort { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            let data = try enc.encode(Persisted(communities: communities, messages: messages, savedAnnouncements: savedAnnouncements, comments: comments))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // demo: ignore
        }
    }

    private func seedIfEmpty() {
        let c = createCommunity(title: "Кино: Обсуждения")
        addPost(communityId: c.id, text: "Добро пожаловать! Здесь можно обсуждать фильмы и делиться рецензиями.")
        addAnnouncement(communityId: c.id, title: "Премьера трейлера", date: Date().addingTimeInterval(60 * 60 * 24 * 3), details: "Официальный трейлер выходит в пятницу.")
    }
}
