import Foundation

enum BackendClientError: Error {
    case invalidURL
    case invalidResponse
    case http(status: Int, body: Data?)
    case notAuthenticated
}

@MainActor
final class BackendClient {
    static let shared = BackendClient()

    private let auth = BackendAuthStore.shared
    private let session: URLSession

    private init() {
        self.session = URLSession(configuration: .default)
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func makeURL(_ path: String) -> URL {
        auth.baseURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path)
    }

    private func request(_ method: String, _ path: String, jsonBody: Data? = nil, authorized: Bool = true) throws -> URLRequest {
        var req = URLRequest(url: makeURL(path))
        req.httpMethod = method
        if let jsonBody {
            req.httpBody = jsonBody
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let t = auth.token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<T: Decodable>(_ req: URLRequest, as: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendClientError.http(status: http.statusCode, body: data)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func sendNoBody(_ req: URLRequest) async throws {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendClientError.http(status: http.statusCode, body: data)
        }
        _ = data
    }

    // MARK: - Uploads

    struct UploadImageOut: Decodable {
        let fileName: String
    }

    func uploadAnnouncementImageJPEG(_ data: Data) async throws -> String {
        try await ensureAuthedOrThrow()
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: makeURL("/uploads/announcement-image"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func add(_ s: String) { body.append(s.data(using: .utf8)!) }

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        add("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        add("\r\n--\(boundary)--\r\n")

        req.httpBody = body
        let out = try await send(req, as: UploadImageOut.self)
        return out.fileName
    }

    // MARK: - Bootstrap auth

    struct AuthOut: Decodable {
        let account_id: String
        let token: String
    }

    struct AuthRegisterIn: Encodable {
        let username: String
        let password: String?
    }

    func ensureAuthed() async {
        if auth.token != nil { return }
        // Best-effort “device-ish” username; backend allows duplicate = login-like.
        let username = "ios-" + UUID().uuidString.lowercased()
        do {
            let body = try encoder.encode(AuthRegisterIn(username: username, password: nil))
            let req = try request("POST", "/auth/register", jsonBody: body, authorized: false)
            let out = try await send(req, as: AuthOut.self)
            auth.token = out.token
            auth.accountId = out.account_id
        } catch {
            // keep silent; UI can still work with local store
        }
    }

    func ensureAuthedOrThrow() async throws {
        await ensureAuthed()
        if auth.token == nil {
            throw BackendClientError.notAuthenticated
        }
    }

    // MARK: - Communities

    struct CommunityCreateIn: Encodable {
        let id: UUID
        let title: String
        let catalogSourceID: String?
    }

    func listCommunities() async throws -> [CommunityChat] {
        try await ensureAuthedOrThrow()
        let req = try request("GET", "/communities")
        return try await send(req, as: [CommunityChat].self)
    }

    func longPollMyCommunities(since: Date?, timeoutSeconds: Int = 25) async throws -> [CommunityChat] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(url: makeURL("/communities/longpoll"), resolvingAgainstBaseURL: false)
        var q: [URLQueryItem] = [
            URLQueryItem(name: "timeoutSeconds", value: String(timeoutSeconds)),
        ]
        if let since {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q.append(URLQueryItem(name: "since", value: f.string(from: since)))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = TimeInterval(max(65, timeoutSeconds + 10))
        return try await send(req, as: [CommunityChat].self)
    }

    func createCommunity(id: UUID, title: String, catalogSourceID: String? = nil) async throws -> CommunityChat {
        try await ensureAuthedOrThrow()
        let body = try encoder.encode(CommunityCreateIn(id: id, title: title, catalogSourceID: catalogSourceID))
        let req = try request("POST", "/communities", jsonBody: body)
        return try await send(req, as: CommunityChat.self)
    }

    func deleteCommunity(id: UUID) async throws {
        try await ensureAuthedOrThrow()
        let req = try request("DELETE", "/communities/\(id.uuidString)")
        try await sendNoBody(req)
    }

    func searchCommunities(query: String, limit: Int = 20) async throws -> [CommunityChat] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(url: makeURL("/communities/search"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        return try await send(req, as: [CommunityChat].self)
    }

    struct MembershipOut: Decodable {
        let community_id: String
        let account_id: String
        let role: String
        let created_at: Date
    }

    struct CommunityUpdateIn: Encodable {
        let title: String
    }

    func updateCommunityTitle(communityId: UUID, title: String) async throws -> CommunityChat {
        try await ensureAuthedOrThrow()
        let body = try encoder.encode(CommunityUpdateIn(title: title))
        let req = try request("PATCH", "/communities/\(communityId.uuidString)", jsonBody: body)
        return try await send(req, as: CommunityChat.self)
    }

    func longPollCommunityMeta(communityId: UUID, since: Date?, timeoutSeconds: Int = 25) async throws -> CommunityChat? {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(
            url: makeURL("/communities/\(communityId.uuidString)/meta/longpoll"),
            resolvingAgainstBaseURL: false
        )
        var q: [URLQueryItem] = [
            URLQueryItem(name: "timeoutSeconds", value: String(timeoutSeconds)),
        ]
        if let since {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q.append(URLQueryItem(name: "since", value: f.string(from: since)))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = TimeInterval(max(65, timeoutSeconds + 10))

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw BackendClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendClientError.http(status: http.statusCode, body: data)
        }
        if data.isEmpty { return nil }
        if let s = String(data: data, encoding: .utf8), s.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            return nil
        }
        return try decoder.decode(CommunityChat.self, from: data)
    }

    func joinCommunity(communityId: UUID) async throws -> MembershipOut {
        try await ensureAuthedOrThrow()
        let req = try request("POST", "/communities/\(communityId.uuidString)/join", jsonBody: nil)
        return try await send(req, as: MembershipOut.self)
    }

    func myMembership(communityId: UUID) async throws -> MembershipOut {
        try await ensureAuthedOrThrow()
        let req = try request("GET", "/communities/\(communityId.uuidString)/my-membership")
        return try await send(req, as: MembershipOut.self)
    }

    // MARK: - Messages

    func listMessages(communityId: UUID, after: Date? = nil, limit: Int = 200) async throws -> [CommunityMessage] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(url: makeURL("/communities/\(communityId.uuidString)/messages"), resolvingAgainstBaseURL: false)
        var q: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let after {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q.append(URLQueryItem(name: "after", value: f.string(from: after)))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        return try await send(req, as: [CommunityMessage].self)
    }

    func longPollMessages(communityId: UUID, after: Date?, timeoutSeconds: Int = 25, limit: Int = 200) async throws -> [CommunityMessage] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(
            url: makeURL("/communities/\(communityId.uuidString)/messages/longpoll"),
            resolvingAgainstBaseURL: false
        )
        var q: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "timeoutSeconds", value: String(timeoutSeconds)),
        ]
        if let after {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q.append(URLQueryItem(name: "after", value: f.string(from: after)))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        // Must exceed server timeout.
        req.timeoutInterval = TimeInterval(max(65, timeoutSeconds + 10))
        return try await send(req, as: [CommunityMessage].self)
    }

    struct PostCreateIn: Encodable {
        let id: UUID
        let text: String
        let spoilerTags: [CommunitySpoilerTag]
    }

    func createPost(communityId: UUID, id: UUID, text: String, spoilerTags: [CommunitySpoilerTag]) async throws -> CommunityMessage {
        try await ensureAuthedOrThrow()
        let body = try encoder.encode(PostCreateIn(id: id, text: text, spoilerTags: spoilerTags))
        let req = try request("POST", "/communities/\(communityId.uuidString)/posts", jsonBody: body)
        return try await send(req, as: CommunityMessage.self)
    }

    struct AnnouncementCreateIn: Encodable {
        let id: UUID
        let text: String?
        let announcement: CommunityAnnouncement
    }

    func createAnnouncement(communityId: UUID, id: UUID, text: String?, announcement: CommunityAnnouncement) async throws -> CommunityMessage {
        try await ensureAuthedOrThrow()
        let body = try encoder.encode(AnnouncementCreateIn(id: id, text: text, announcement: announcement))
        let req = try request("POST", "/communities/\(communityId.uuidString)/announcements", jsonBody: body)
        return try await send(req, as: CommunityMessage.self)
    }

    // MARK: - Comments

    func listComments(messageId: UUID, threadParentCommentId: UUID?, limit: Int = 500) async throws -> [CommunityComment] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(url: makeURL("/messages/\(messageId.uuidString)/comments"), resolvingAgainstBaseURL: false)
        var q: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let threadParentCommentId {
            q.append(URLQueryItem(name: "threadParentCommentId", value: threadParentCommentId.uuidString))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        return try await send(req, as: [CommunityComment].self)
    }

    func longPollComments(
        messageId: UUID,
        threadParentCommentId: UUID?,
        after: Date?,
        timeoutSeconds: Int = 25,
        limit: Int = 500
    ) async throws -> [CommunityComment] {
        try await ensureAuthedOrThrow()
        var comps = URLComponents(url: makeURL("/messages/\(messageId.uuidString)/comments/longpoll"), resolvingAgainstBaseURL: false)
        var q: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "timeoutSeconds", value: String(timeoutSeconds)),
        ]
        if let threadParentCommentId {
            q.append(URLQueryItem(name: "threadParentCommentId", value: threadParentCommentId.uuidString))
        }
        if let after {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            q.append(URLQueryItem(name: "after", value: f.string(from: after)))
        }
        comps?.queryItems = q
        guard let url = comps?.url else { throw BackendClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("Bearer \(auth.token!)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = TimeInterval(max(65, timeoutSeconds + 10))
        return try await send(req, as: [CommunityComment].self)
    }

    struct CommentCreateIn: Encodable {
        let id: UUID
        let threadParentCommentId: UUID?
        let text: String
    }

    func createComment(messageId: UUID, id: UUID, threadParentCommentId: UUID?, text: String) async throws -> CommunityComment {
        try await ensureAuthedOrThrow()
        let body = try encoder.encode(CommentCreateIn(id: id, threadParentCommentId: threadParentCommentId, text: text))
        let req = try request("POST", "/messages/\(messageId.uuidString)/comments", jsonBody: body)
        return try await send(req, as: CommunityComment.self)
    }
}

