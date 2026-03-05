// CookieManager.swift — Sole read/write point for App Group cookies (Services layer)
// All cookie persistence is funnelled through this type.
// Views and other services must never access UserDefaults or the App Group directly.

import Foundation
import WebKit

// MARK: - Storage abstraction (enables testing without UserDefaults in test files)

/// A minimal key-value storage abstraction used by CookieManager.
/// The production implementation wraps UserDefaults(suiteName:).
/// Tests supply an in-memory mock that conforms to this protocol.
public protocol CookieStorage {
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
    func removeObject(forKey key: String)
}

/// Wraps the shared App Group UserDefaults to conform to CookieStorage.
/// This is the only place in the codebase that names UserDefaults or the App Group suite.
final class AppGroupStorage: CookieStorage {
    private let defaults: UserDefaults

    init() {
        guard let suite = UserDefaults(suiteName: "group.com.piper.app") else {
            fatalError("CookieManager: could not open UserDefaults for group.com.piper.app")
        }
        self.defaults = suite
    }

    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ value: Data?, forKey key: String) { defaults.set(value, forKey: key) }
    func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
}

// MARK: - CookieManager

/// Manages cookie persistence in the shared App Group.
///
/// Cookies are serialized as an array of property dictionaries and stored
/// under `cookiesKey`. Only cookies whose domain contains ".x.com" or
/// ".twitter.com" are persisted.
public final class CookieManager {

    // MARK: - Constants

    /// The UserDefaults key under which serialized cookies are stored.
    static let cookiesKey = "piper.cookies"

    /// Domains considered valid X/Twitter cookie domains.
    static let allowedDomains: [String] = [".x.com", ".twitter.com"]

    // MARK: - Storage

    private let storage: CookieStorage

    /// Initialises CookieManager backed by the real App Group storage.
    public convenience init() {
        self.init(storage: AppGroupStorage())
    }

    /// Initialises CookieManager with an injectable storage (used in tests).
    public init(storage: CookieStorage) {
        self.storage = storage
    }

    // MARK: - Public API

    /// Returns `true` when at least one cookie is currently stored.
    public var hasCookies: Bool {
        !loadCookies().isEmpty
    }

    /// Persists `cookies` to the App Group, replacing any previously stored cookies.
    /// Only X/Twitter-domain cookies are retained.
    public func saveCookies(_ cookies: [HTTPCookie]) {
        let filtered = cookies.filter { cookie in
            CookieManager.allowedDomains.contains(where: {
                cookie.domain.hasSuffix($0) || cookie.domain == String($0.dropFirst())
            })
        }
        let serialized = filtered.map { $0.properties ?? [:] }
        let encoded = try? NSKeyedArchiver.archivedData(withRootObject: serialized, requiringSecureCoding: false)
        storage.set(encoded, forKey: CookieManager.cookiesKey)
    }

    /// Loads and deserialises cookies from storage.
    /// Returns an empty array if nothing is stored or if data is corrupt.
    public func loadCookies() -> [HTTPCookie] {
        guard let data = storage.data(forKey: CookieManager.cookiesKey) else {
            return []
        }
        guard
            let raw = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let propertiesArray = raw as? [[HTTPCookiePropertyKey: Any]]
        else {
            return []
        }
        return propertiesArray.compactMap { HTTPCookie(properties: $0) }
    }

    /// Removes all stored cookies.
    public func clearCookies() {
        storage.removeObject(forKey: CookieManager.cookiesKey)
    }

    // MARK: - WKWebView helpers

    /// Extracts cookies from `cookieStore`, filters to X/Twitter domains, and persists them.
    public func extractAndSave(from cookieStore: WKHTTPCookieStore, completion: @escaping () -> Void) {
        cookieStore.getAllCookies { [weak self] cookies in
            self?.saveCookies(cookies)
            completion()
        }
    }
}
