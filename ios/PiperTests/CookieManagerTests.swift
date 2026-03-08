// CookieManagerTests.swift — Unit tests for CookieManager (Services layer)
// Uses an in-memory mock CookieStorage (InMemoryStorage) so tests are fully isolated.
// Also verifies that the production init uses UserDefaults.standard (not an App Group).

import XCTest
import WebKit
@testable import Piper

// MARK: - In-memory mock storage (conforms to CookieStorage)

final class InMemoryStorage: CookieStorage {
    private var store: [String: Data] = [:]

    func data(forKey key: String) -> Data? { store[key] }

    func set(_ value: Data?, forKey key: String) {
        if let v = value { store[key] = v } else { store.removeValue(forKey: key) }
    }

    func removeObject(forKey key: String) { store.removeValue(forKey: key) }
}

// MARK: - Tests

final class CookieManagerTests: XCTestCase {

    private var storage: InMemoryStorage!
    private var sut: CookieManager!

    override func setUp() {
        super.setUp()
        storage = InMemoryStorage()
        sut = CookieManager(storage: storage)
    }

    override func tearDown() {
        storage = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Factory helpers

    private func makeCookie(name: String, domain: String) -> HTTPCookie {
        HTTPCookie(properties: [
            .name: name,
            .value: "value-\(name)",
            .domain: domain,
            .path: "/",
        ])!
    }

    // MARK: - Test 1: Save and load round-trip

    func testSaveAndLoadRoundTrip() {
        let cookie = makeCookie(name: "auth_token", domain: ".x.com")
        sut.saveCookies([cookie])

        let loaded = sut.loadCookies()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "auth_token")
        XCTAssertEqual(loaded.first?.domain, ".x.com")
    }

    // MARK: - Test 2: Load when nothing saved

    func testLoadWhenNothingSaved() {
        let cookies = sut.loadCookies()
        XCTAssertTrue(cookies.isEmpty)
    }

    // MARK: - Test 3: Save overwrites previous

    func testSaveOverwritesPrevious() {
        let cookieA = makeCookie(name: "token_a", domain: ".x.com")
        sut.saveCookies([cookieA])

        let cookieB = makeCookie(name: "token_b", domain: ".x.com")
        sut.saveCookies([cookieB])

        let loaded = sut.loadCookies()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "token_b")
    }

    // MARK: - Test 4: Clear cookies

    func testClearCookies() {
        let cookie = makeCookie(name: "auth_token", domain: ".x.com")
        sut.saveCookies([cookie])
        XCTAssertFalse(sut.loadCookies().isEmpty)

        sut.clearCookies()
        XCTAssertTrue(sut.loadCookies().isEmpty)
    }

    // MARK: - Test 5: Handles corrupt data

    func testHandlesCorruptData() {
        // Write garbage bytes directly into the in-memory store.
        storage.set(Data([0xDE, 0xAD, 0xBE, 0xEF]), forKey: CookieManager.cookiesKey)

        let cookies = sut.loadCookies()
        // Must return empty array without crashing.
        XCTAssertTrue(cookies.isEmpty)
    }

    // MARK: - Test 6: hasCookies returns true when cookies are present

    func testHasCookiesReturnsTrueWhenPresent() {
        let cookie = makeCookie(name: "auth_token", domain: ".x.com")
        sut.saveCookies([cookie])
        XCTAssertTrue(sut.hasCookies)
    }

    // MARK: - Test 7: hasCookies returns false when empty

    func testHasCookiesReturnsFalseWhenEmpty() {
        XCTAssertFalse(sut.hasCookies)
    }

    // MARK: - Test 8: Cookie domain filtering

    func testCookieDomainFiltering() {
        let xCookie       = makeCookie(name: "x_token",      domain: ".x.com")
        let twitterCookie = makeCookie(name: "twitter_token", domain: ".twitter.com")
        let googleCookie  = makeCookie(name: "google_token",  domain: ".google.com")

        sut.saveCookies([xCookie, twitterCookie, googleCookie])

        let loaded = sut.loadCookies()
        XCTAssertEqual(loaded.count, 2)

        let names = Set(loaded.map(\.name))
        XCTAssertTrue(names.contains("x_token"))
        XCTAssertTrue(names.contains("twitter_token"))
        XCTAssertFalse(names.contains("google_token"))
    }

    // MARK: - Test 9: Production init uses UserDefaults.standard (not an App Group)

    func testProductionInitUsesStandardUserDefaults() {
        // Write a cookie via the production CookieManager (StandardStorage).
        let productionManager = CookieManager()
        let key = CookieManager.cookiesKey

        // Start clean.
        productionManager.clearCookies()
        XCTAssertNil(UserDefaults.standard.data(forKey: key),
                     "Should start with no data in UserDefaults.standard")

        // Save a cookie and verify it lands in UserDefaults.standard.
        let cookie = makeCookie(name: "prod_test", domain: ".x.com")
        productionManager.saveCookies([cookie])

        XCTAssertNotNil(UserDefaults.standard.data(forKey: key),
                        "Cookie data must be stored in UserDefaults.standard, not an App Group")

        // Clean up.
        productionManager.clearCookies()
    }
}
