import Foundation

enum YandexMapsURL {
    static func point(latitude: Double, longitude: Double) -> URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "yandex.ru"
        c.path = "/maps/"
        c.queryItems = [
            URLQueryItem(name: "pt", value: "\(longitude),\(latitude)"),
            URLQueryItem(name: "z", value: "16"),
            URLQueryItem(name: "l", value: "map")
        ]
        return c.url ?? URL(string: "https://yandex.ru/maps/")!
    }
}
