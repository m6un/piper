import Foundation

/// CookieManager is the sole read/write point for App Group cookies.
/// Only this file may reference UserDefaults or the App Group identifier.
public enum CookieManager {

    private static let suiteName = "group.com.piper.app"
    private static let cookiesKey = "cookies"

    /// Serializes an array of HTTPCookie values and writes them to the shared
    /// App Group UserDefaults so that the Share Extension can read them.
    public static func save(_ cookies: [HTTPCookie]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let serialized: [[String: Any]] = cookies.compactMap { cookie in
            guard let props = cookie.properties else { return nil }
            // Convert HTTPCookiePropertyKey keys to String for plist storage
            var dict = [String: Any]()
            for (key, value) in props {
                dict[key.rawValue] = value
            }
            return dict
        }

        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: serialized,
            format: .binary,
            options: 0
        ) else { return }

        defaults.set(data, forKey: cookiesKey)
    }

    /// Loads and deserializes cookies previously saved by `save(_:)`.
    /// Returns an empty array when no cookies have been saved.
    public static func load() -> [HTTPCookie] {
        guard
            let defaults = UserDefaults(suiteName: suiteName),
            let data = defaults.data(forKey: cookiesKey),
            let list = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [[String: Any]]
        else { return [] }

        return list.compactMap { dict in
            var props = [HTTPCookiePropertyKey: Any]()
            for (key, value) in dict {
                props[HTTPCookiePropertyKey(key)] = value
            }
            return HTTPCookie(properties: props)
        }
    }
}
