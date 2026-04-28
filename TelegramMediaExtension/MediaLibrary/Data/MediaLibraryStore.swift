import Combine
import Foundation

/// Хранилище каталога (аналог «состояния» модуля в Telegram: отдельный слой от UI).
@MainActor
final class MediaLibraryStore: ObservableObject {
    static let shared = MediaLibraryStore()

    @Published private(set) var items: [MediaItem] = []

    private let fileURL: URL
    private var isLoaded = false

    private init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = base.appendingPathComponent("media_library.json")
    }

    func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([MediaItem].self, from: data)
            self.items = decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
        } catch {
            self.items = []
        }
    }

    func loadIfNeededAsync() async {
        guard !isLoaded else { return }
        isLoaded = true
        let url = fileURL
        let decoded: [MediaItem] = await Task.detached(priority: .utility) {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([MediaItem].self, from: data)
            } catch {
                return []
            }
        }.value
        self.items = decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    /// Принудительно перечитать с диска (если данные могли измениться извне).
    func reloadFromDisk() {
        isLoaded = true
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([MediaItem].self, from: data)
            self.items = decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
        } catch {
            self.items = []
        }
    }

    func reloadFromDiskAsync() async {
        isLoaded = true
        let url = fileURL
        let decoded: [MediaItem] = await Task.detached(priority: .utility) {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([MediaItem].self, from: data)
            } catch {
                return []
            }
        }.value
        self.items = decoded.sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func item(id: UUID) -> MediaItem? {
        loadIfNeeded()
        return items.first { $0.id == id }
    }

    func item(catalogSourceID: String) -> MediaItem? {
        loadIfNeeded()
        return items.first { $0.catalogSourceID == catalogSourceID }
    }

    func totalItemCount() -> Int {
        loadIfNeeded()
        return items.count
    }

    func upsert(_ item: MediaItem) {
        loadIfNeeded()
        var item = item
        item.updatedAt = Date()

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
        persist()
    }

    func delete(id: UUID) {
        loadIfNeeded()
        if let item = items.first(where: { $0.id == id }),
           let url = Self.coverImageURL(fileName: item.coverFileName) {
            try? FileManager.default.removeItem(at: url)
        }
        items.removeAll(where: { $0.id == id })
        persist()
    }

    /// Каталог JPEG-обложек (Application Support).
    static var coversDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("TelegramMediaExtension", isDirectory: true)
        return root.appendingPathComponent("MediaCovers", isDirectory: true)
    }

    static func coverImageURL(fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return coversDirectoryURL.appendingPathComponent(fileName)
    }

    func saveCoverJPEG(_ data: Data) throws -> String {
        try FileManager.default.createDirectory(at: Self.coversDirectoryURL, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        try data.write(to: Self.coversDirectoryURL.appendingPathComponent(name), options: [.atomic])
        return name
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Demo: игнорируем ошибки записи
        }
    }
}
