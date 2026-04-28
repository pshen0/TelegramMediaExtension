import Foundation

@MainActor
final class BackendAuthStore {
    static let shared = BackendAuthStore()

    private enum Keys {
        static let token = "tme.backend.token"
        static let accountId = "tme.backend.accountId"
        static let baseURL = "tme.backend.baseURL"
    }

    private init() {}

    var token: String? {
        get { UserDefaults.standard.string(forKey: Keys.token) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Keys.token)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.token)
            }
        }
    }

    var accountId: String? {
        get { UserDefaults.standard.string(forKey: Keys.accountId) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Keys.accountId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.accountId)
            }
        }
    }

    var baseURL: URL {
        get {
            if let raw = UserDefaults.standard.string(forKey: Keys.baseURL),
               let u = URL(string: raw) {
                return u
            }
            return URL(string: "http://127.0.0.1:8000")!
        }
        set {
            UserDefaults.standard.set(newValue.absoluteString, forKey: Keys.baseURL)
        }
    }
}

