import Foundation
import UIKit

enum MediaLibraryHeaderBannerColor {
    private static let legacyDefaultsKey = "MediaLibrary.bannerHeaderRGBA"
    private static let defaultsBackupKey = "MediaLibrary.bannerHeaderRGBA.defaultsBackup"
    private static let accentFileName = "banner_accent_color.json"

    private struct StoredRGBA: Codable {
        let r: Double
        let g: Double
        let b: Double
        let a: Double
    }

    private static func accentFileURL() throws -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TelegramMediaExtension", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(accentFileName)
    }

    static func defaultFallback(for trait: UITraitCollection) -> UIColor {
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1)
        }
        return UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1)
    }

    static func catalogChromeAccent(for trait: UITraitCollection) -> UIColor {
        resolved(for: trait)
    }

    static func resolved(for trait: UITraitCollection) -> UIColor {
        if let rgba = loadFromUserData() {
            return UIColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
        }
        if migrateLegacyDefaultsIfNeeded() != nil {
            return resolved(for: trait)
        }
        return defaultFallback(for: trait)
    }

    static func setCustom(_ color: UIColor) {
        let c = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if c.getRed(&r, green: &g, blue: &b, alpha: &a) {
            savePersisted(StoredRGBA(r: Double(r), g: Double(g), b: Double(b), a: Double(a)))
        } else if let comps = c.cgColor.components, comps.count >= 3 {
            let rr = Double(comps[0])
            let gg = Double(comps.count > 2 ? comps[1] : comps[0])
            let bb = Double(comps.count > 2 ? comps[2] : comps[0])
            let aa = Double(comps.count > 3 ? comps[3] : 1)
            savePersisted(StoredRGBA(r: rr, g: gg, b: bb, a: aa))
        }
        NotificationCenter.default.post(name: .mediaLibraryBannerColorDidChange, object: nil)
    }

    static func clearCustom() {
        try? FileManager.default.removeItem(at: accentFileURL())
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        UserDefaults.standard.removeObject(forKey: defaultsBackupKey)
        NotificationCenter.default.post(name: .mediaLibraryBannerColorDidChange, object: nil)
    }

    static func hasCustomColor() -> Bool {
        loadFromUserData() != nil
    }

    private static func savePersisted(_ value: StoredRGBA) {
        if persistToDisk(value) {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        } else {
            UserDefaults.standard.set(
                [CGFloat(value.r), CGFloat(value.g), CGFloat(value.b), CGFloat(value.a)],
                forKey: defaultsBackupKey
            )
        }
    }

    private static func persistToDisk(_ value: StoredRGBA) -> Bool {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: accentFileURL(), options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    private static func loadFromUserData() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        if let rgba = loadFromDiskFile() {
            return rgba
        }
        if let rgba = rgbaArray(from: defaultsBackupKey) {
            return rgba
        }
        return rgbaArray(from: legacyDefaultsKey)
    }

    private static func loadFromDiskFile() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        do {
            let data = try Data(contentsOf: accentFileURL())
            let v = try JSONDecoder().decode(StoredRGBA.self, from: data)
            return (CGFloat(v.r), CGFloat(v.g), CGFloat(v.b), CGFloat(v.a))
        } catch {
            return nil
        }
    }

    private static func rgbaArray(from key: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [CGFloat], arr.count == 4 else { return nil }
        return (arr[0], arr[1], arr[2], arr[3])
    }

    @discardableResult
    private static func migrateLegacyDefaultsIfNeeded() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let rgba = rgbaArray(from: legacyDefaultsKey) else { return nil }
        if persistToDisk(StoredRGBA(r: Double(rgba.r), g: Double(rgba.g), b: Double(rgba.b), a: Double(rgba.a))) {
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        }
        return rgba
    }

    static let posterPlaceholderFillAlpha: CGFloat = 0.12

    static func posterPlaceholderTint(for trait: UITraitCollection) -> UIColor {
        resolved(for: trait).resolvedColor(with: trait)
    }

    static func posterPlaceholderFill(for trait: UITraitCollection) -> UIColor {
        posterPlaceholderTint(for: trait).withAlphaComponent(posterPlaceholderFillAlpha)
    }
}

extension Notification.Name {
    static let mediaLibraryBannerColorDidChange = Notification.Name("MediaLibraryBannerColorDidChange")
}
