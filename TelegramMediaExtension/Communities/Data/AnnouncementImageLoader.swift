import Foundation
import UIKit

@MainActor
final class AnnouncementImageLoader {
    static let shared = AnnouncementImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: [((UIImage?) -> Void)]] = [:]

    private init() {
        cache.countLimit = 200
    }

    func cachedImage(fileName: String) -> UIImage? {
        cache.object(forKey: fileName as NSString)
    }

    func load(fileName: String, completion: @escaping (UIImage?) -> Void) {
        if let img = cachedImage(fileName: fileName) {
            completion(img)
            return
        }

        if inFlight[fileName] != nil {
            inFlight[fileName]?.append(completion)
            return
        }
        inFlight[fileName] = [completion]

        let localURL = CommunityStore.announcementImageURL(fileName: fileName)
        let remoteURL = BackendAuthStore.shared.baseURL
            .appendingPathComponent("media", isDirectory: true)
            .appendingPathComponent("announcement-images", isDirectory: true)
            .appendingPathComponent(fileName)

        Task.detached { [fileName, localURL, remoteURL] in
            if let url = localURL,
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                await MainActor.run {
                    AnnouncementImageLoader.shared.cache.setObject(img, forKey: fileName as NSString)
                    AnnouncementImageLoader.shared.finish(fileName: fileName, image: img)
                }
                return
            }

            do {
                let (data, _) = try await URLSession.shared.data(from: remoteURL)
                let img = UIImage(data: data)
                if let img {
                    await MainActor.run {
                        CommunityStore.shared.cacheAnnouncementImage(data: data, fileName: fileName)
                        AnnouncementImageLoader.shared.cache.setObject(img, forKey: fileName as NSString)
                        AnnouncementImageLoader.shared.finish(fileName: fileName, image: img)
                    }
                } else {
                    await MainActor.run { AnnouncementImageLoader.shared.finish(fileName: fileName, image: nil) }
                }
            } catch {
                await MainActor.run { AnnouncementImageLoader.shared.finish(fileName: fileName, image: nil) }
            }
        }
    }

    private func finish(fileName: String, image: UIImage?) {
        let callbacks = inFlight[fileName] ?? []
        inFlight[fileName] = nil
        callbacks.forEach { $0(image) }
    }
}

