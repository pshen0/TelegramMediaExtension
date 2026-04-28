import Combine
import Foundation

@MainActor
final class CommunityStore: ObservableObject {
    static let shared = CommunityStore()

    @Published private(set) var communities: [CommunityChat] = []
    @Published private(set) var messages: [CommunityMessage] = []
    @Published private(set) var savedAnnouncements: [SavedAnnouncement] = []
    @Published private(set) var comments: [CommunityComment] = []
    @Published private(set) var membershipRoles: [UUID: String] = [:]

    private let backend = BackendClient.shared
    private let fileURL: URL
    private var isLoaded = false
    private var didTryBackendBootstrap = false

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

    func cacheAnnouncementImage(data: Data, fileName: String) {
        do {
            try FileManager.default.createDirectory(at: Self.announcementImagesDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: Self.announcementImagesDirectoryURL.appendingPathComponent(fileName), options: [.atomic])
        } catch {
            //
        }
    }

    func ensureAnnouncementImageCached(fileName: String) async {
        guard let localURL = Self.announcementImageURL(fileName: fileName) else { return }
        if FileManager.default.fileExists(atPath: localURL.path) { return }
        do {
            let url = BackendAuthStore.shared.baseURL
                .appendingPathComponent("media", isDirectory: true)
                .appendingPathComponent("announcement-images", isDirectory: true)
                .appendingPathComponent(fileName)
            let (data, _) = try await URLSession.shared.data(from: url)
            cacheAnnouncementImage(data: data, fileName: fileName)
        } catch {
            //
        }
    }

    // MARK: - Community avatars

    static var communityAvatarsDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("TelegramMediaExtension", isDirectory: true)
        return root.appendingPathComponent("CommunityAvatars", isDirectory: true)
    }

    static func communityAvatarURL(fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return communityAvatarsDirectoryURL.appendingPathComponent(fileName)
    }

    func setCommunityAvatar(communityId: UUID, jpegData: Data) throws {
        loadIfNeeded()
        guard let i = communities.firstIndex(where: { $0.id == communityId }) else { return }
        try FileManager.default.createDirectory(at: Self.communityAvatarsDirectoryURL, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        let url = Self.communityAvatarsDirectoryURL.appendingPathComponent(name)
        try jpegData.write(to: url, options: [.atomic])
        if let old = communities[i].avatarFileName, let oldURL = Self.communityAvatarURL(fileName: old) {
            try? FileManager.default.removeItem(at: oldURL)
        }
        communities[i].avatarFileName = name
        communities[i].updatedAt = Date()
        persist()
    }

    func clearCommunityAvatar(communityId: UUID) {
        loadIfNeeded()
        guard let i = communities.firstIndex(where: { $0.id == communityId }) else { return }
        if let old = communities[i].avatarFileName, let u = Self.communityAvatarURL(fileName: old) {
            try? FileManager.default.removeItem(at: u)
        }
        communities[i].avatarFileName = nil
        communities[i].updatedAt = Date()
        persist()
    }

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        reloadFromDisk()
        bootstrapBackendIfPossible()
    }

    func loadIfNeededAsync() async {
        guard !isLoaded else { return }
        isLoaded = true
        let url = fileURL
        let decoded: Persisted? = await Task.detached(priority: .utility) {
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(Persisted.self, from: data)
            } catch {
                return nil
            }
        }.value
        if let decoded {
            communities = decoded.communities.sorted { $0.updatedAt > $1.updatedAt }
            messages = decoded.messages.sorted { $0.createdAt < $1.createdAt }
            savedAnnouncements = decoded.savedAnnouncements.sorted { $0.date < $1.date }
            comments = decoded.comments.sorted { $0.createdAt < $1.createdAt }
        } else {
            communities = []
            messages = []
            savedAnnouncements = []
            comments = []
        }
        bootstrapBackendIfPossible()
    }

    private func bootstrapBackendIfPossible() {
        guard !didTryBackendBootstrap else { return }
        didTryBackendBootstrap = true
        Task { [weak self] in
            guard let self else { return }
            await backend.ensureAuthed()
            await self.refreshCommunities()
        }
    }

    // MARK: - Backend sync

    func refreshCommunities() async {
        do {
            let remote = try await backend.listCommunities()
            communities = remote.sorted { $0.updatedAt > $1.updatedAt }
            persist()
        } catch {
            //
        }
    }

    func longPollMyCommunities() async throws {
        let since = communities.map(\.updatedAt).max()
        let remote = try await backend.longPollMyCommunities(since: since, timeoutSeconds: 25)
        guard !remote.isEmpty else { return }
        for c in remote {
            upsertCommunity(c)
            await refreshNewMessages(communityId: c.id)
            if let lastMsg = lastMessage(for: c.id) {
                await refreshComments(messageId: lastMsg.id, threadParentCommentId: nil)
            }
        }
        communities.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func refreshMyMembershipRole(communityId: UUID) async {
        do {
            let m = try await backend.myMembership(communityId: communityId)
            membershipRoles[communityId] = m.role
        } catch {
            membershipRoles.removeValue(forKey: communityId)
        }
    }

    func canSendMessages(in communityId: UUID) -> Bool {
        membershipRoles[communityId] != "reader"
    }

    func refreshMessages(communityId: UUID) async {
        do {
            let remote = try await backend.listMessages(communityId: communityId, after: nil, limit: 200)
            // Replace messages for this community, keep others.
            messages.removeAll(where: { $0.communityId == communityId })
            messages.append(contentsOf: remote)
            messages.sort { $0.createdAt < $1.createdAt }
            touchCommunity(communityId)
            persist()
        } catch {
            //
        }
    }

    func refreshNewMessages(communityId: UUID) async {
        let last = messages(for: communityId).last?.createdAt
        do {
            let remote = try await backend.listMessages(communityId: communityId, after: last, limit: 200)
            guard !remote.isEmpty else { return }

            let existingIds = Set(messages.filter { $0.communityId == communityId }.map(\.id))
            let fresh = remote.filter { !existingIds.contains($0.id) }
            guard !fresh.isEmpty else { return }

            messages.append(contentsOf: fresh)
            messages.sort { $0.createdAt < $1.createdAt }
            touchCommunity(communityId)
            persist()
        } catch {
            //
        }
    }

    func longPollNewMessages(communityId: UUID) async throws {
        let last = messages(for: communityId).last?.createdAt
        let remote = try await backend.longPollMessages(communityId: communityId, after: last, timeoutSeconds: 25, limit: 200)
        guard !remote.isEmpty else { return }

        let existingIds = Set(messages.filter { $0.communityId == communityId }.map(\.id))
        let fresh = remote.filter { !existingIds.contains($0.id) }
        guard !fresh.isEmpty else { return }

        messages.append(contentsOf: fresh)
        messages.sort { $0.createdAt < $1.createdAt }
        touchCommunity(communityId)
        persist()
    }

    func refreshComments(messageId: UUID, threadParentCommentId: UUID?) async {
        do {
            let remote = try await backend.listComments(messageId: messageId, threadParentCommentId: threadParentCommentId, limit: 500)
            // Replace comments for that thread only.
            comments.removeAll(where: { $0.messageId == messageId && $0.threadParentCommentId == threadParentCommentId })
            comments.append(contentsOf: remote)
            comments.sort { $0.createdAt < $1.createdAt }
            persist()
        } catch {
            //
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
        membershipRoles[c.id] = "publisher"
        persist()
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await backend.createCommunity(id: c.id, title: c.title, catalogSourceID: c.catalogSourceID)
                await self.refreshCommunities()
                await self.refreshMyMembershipRole(communityId: c.id)
            } catch {
                //
            }
        }
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

    func setCommunityTitle(communityId: UUID, title: String) {
        loadIfNeeded()
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = communities.firstIndex(where: { $0.id == communityId }) else { return }
        communities[i].title = t
        communities[i].updatedAt = Date()
        persist()
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await backend.updateCommunityTitle(communityId: communityId, title: t)
                await self.refreshCommunities()
            } catch {
                //
            }
        }
    }

    func longPollCommunityMeta(communityId: UUID) async throws {
        let since = communities.first(where: { $0.id == communityId })?.updatedAt
        if let updated = try await backend.longPollCommunityMeta(communityId: communityId, since: since, timeoutSeconds: 25) {
            upsertCommunity(updated)
        }
    }

    func longPollNewComments(messageId: UUID, threadParentCommentId: UUID?) async throws {
        let last = comments(for: messageId, threadParentCommentId: threadParentCommentId).last?.createdAt
        let remote = try await backend.longPollComments(
            messageId: messageId,
            threadParentCommentId: threadParentCommentId,
            after: last,
            timeoutSeconds: 25,
            limit: 500
        )
        guard !remote.isEmpty else { return }

        let existingIds = Set(
            comments
                .filter { $0.messageId == messageId && $0.threadParentCommentId == threadParentCommentId }
                .map(\.id)
        )
        let fresh = remote.filter { !existingIds.contains($0.id) }
        guard !fresh.isEmpty else { return }

        comments.append(contentsOf: fresh)
        comments.sort { $0.createdAt < $1.createdAt }
        if let communityId = messages.first(where: { $0.id == messageId })?.communityId {
            touchCommunity(communityId)
        }
        persist()
    }

    func deleteCommunity(id: UUID) {
        loadIfNeeded()
        if let old = communities.first(where: { $0.id == id })?.avatarFileName, let u = Self.communityAvatarURL(fileName: old) {
            try? FileManager.default.removeItem(at: u)
        }
        let messageIds = messages.filter { $0.communityId == id }.map(\.id)
        communities.removeAll(where: { $0.id == id })
        messages.removeAll(where: { $0.communityId == id })
        if !messageIds.isEmpty {
            let set = Set(messageIds)
            comments.removeAll(where: { set.contains($0.messageId) })
        }
        persist()
        Task {
            try? await backend.deleteCommunity(id: id)
        }
    }

    func messages(for communityId: UUID) -> [CommunityMessage] {
        loadIfNeeded()
        return messages.filter { $0.communityId == communityId }.sorted { $0.createdAt < $1.createdAt }
    }

    func lastMessage(for communityId: UUID) -> CommunityMessage? {
        messages(for: communityId).last
    }

    func listPreviewText(for communityId: UUID) -> String {
        guard let m = lastMessage(for: communityId) else { return "Нет сообщений" }
        // If there are comments on the latest message, show last comment as the preview.
        if let lastComment = comments.filter({ $0.messageId == m.id && $0.threadParentCommentId == nil }).last {
            return lastComment.text
        }
        switch m.kind {
        case .post:
            return m.text
        case .announcement:
            guard let a = m.announcement else { return m.text }
            let body = (a.details?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? m.text
            if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Анонс: \(a.title)"
            }
            return body
        }
    }

    func comments(for messageId: UUID, threadParentCommentId: UUID? = nil) -> [CommunityComment] {
        loadIfNeeded()
        return comments
            .filter { $0.messageId == messageId && $0.threadParentCommentId == threadParentCommentId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func addComment(messageId: UUID, threadParentCommentId: UUID? = nil, text: String) {
        loadIfNeeded()
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let local = CommunityComment(messageId: messageId, threadParentCommentId: threadParentCommentId, text: t)
        comments.append(local)
        persist()
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await backend.createComment(messageId: messageId, id: local.id, threadParentCommentId: threadParentCommentId, text: t)
                await self.refreshComments(messageId: messageId, threadParentCommentId: threadParentCommentId)
                // bump community ordering/preview
                if let communityId = self.messages.first(where: { $0.id == messageId })?.communityId {
                    self.touchCommunity(communityId)
                    self.persist()
                }
            } catch {
                // ignore
            }
        }
    }

    func addPost(communityId: UUID, text: String, spoilerTags: [CommunitySpoilerTag] = []) {
        loadIfNeeded()
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let m = CommunityMessage(communityId: communityId, kind: .post, text: t, spoilerTags: spoilerTags)
        messages.append(m)
        touchCommunity(communityId)
        persist()
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await backend.createPost(communityId: communityId, id: m.id, text: t, spoilerTags: spoilerTags)
                await self.refreshMessages(communityId: communityId)
            } catch {
                //
            }
        }
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
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await backend.createAnnouncement(communityId: communityId, id: m.id, text: m.text, announcement: a)
                await self.refreshMessages(communityId: communityId)
            } catch {
                // ignore
            }
        }
    }

    func addPersonalAnnouncement(
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

        let fp = Self.announcementFingerprint(
            title: t,
            date: date,
            details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
            imageFileName: imageFileName,
            linkURL: linkURL,
            location: location
        )
        if savedAnnouncements.contains(where: { Self.savedFingerprint($0) == fp }) {
            return
        }

        savedAnnouncements.append(
            SavedAnnouncement(
                sourceCommunityId: nil,
                sourceMessageId: nil,
                title: t,
                date: date,
                details: details?.trimmingCharacters(in: .whitespacesAndNewlines),
                imageFileName: imageFileName,
                linkURL: linkURL,
                location: location
            )
        )
        savedAnnouncements.sort { $0.date < $1.date }
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

    func updateSavedAnnouncement(
        id: UUID,
        title: String,
        date: Date,
        details: String?,
        imageFileName: String?,
        linkURL: String?,
        location: CommunityLocation?
    ) {
        loadIfNeeded()
        guard let i = savedAnnouncements.firstIndex(where: { $0.id == id }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let old = savedAnnouncements[i]
        let oldImage = old.imageFileName
        var next = old
        next.title = t
        next.date = date
        let trimmedDetails = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        next.details = (trimmedDetails?.isEmpty == false) ? trimmedDetails : nil
        next.imageFileName = imageFileName
        let trimmedLink = linkURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        next.linkURL = (trimmedLink?.isEmpty == false) ? trimmedLink : nil
        next.location = location

        if let oldName = oldImage, oldName != next.imageFileName, let url = Self.announcementImageURL(fileName: oldName) {
            try? FileManager.default.removeItem(at: url)
        }

        savedAnnouncements[i] = next
        savedAnnouncements.sort { $0.date < $1.date }
        persist()
    }

    func communityTitle(id: UUID?) -> String? {
        guard let id else { return nil }
        loadIfNeeded()
        return communities.first(where: { $0.id == id })?.title
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
            //
        }
    }
}
