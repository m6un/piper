import XCTest
@testable import Piper

/// Unit test stubs specifying the expected behaviour of CookieManager.
/// These tests are a specification; they require an App Group entitlement
/// and a simulator/device to run end-to-end.
final class CookieManagerTests: XCTestCase {

    // MARK: - Helpers

    /// Clears any cookies written by previous test runs so each test starts fresh.
    /// Uses CookieManager itself — no direct storage access from tests.
    private func clearStoredCookies() {
        CookieManager.save([])
    }

    private func makeCookie(name: String, value: String, domain: String = "x.com") -> HTTPCookie? {
        HTTPCookie(properties: [
            .name: name,
            .value: value,
            .domain: domain,
            .path: "/",
        ])
    }

    // MARK: - Tests

    /// `load()` returns an empty array when no cookies have ever been saved.
    func test_load_returnsEmptyArray_whenNothingStored() {
        clearStoredCookies()

        let result = CookieManager.load()

        XCTAssertTrue(result.isEmpty, "Expected no cookies when nothing has been saved")
    }

    /// Cookies saved via `save(_:)` are retrievable via `load()`.
    func test_saveAndLoad_roundtrip() throws {
        clearStoredCookies()

        let cookie = try XCTUnwrap(makeCookie(name: "auth_token", value: "abc123"))
        CookieManager.save([cookie])

        let loaded = CookieManager.load()

        XCTAssertFalse(loaded.isEmpty, "Expected at least one cookie after save")
        let match = loaded.first { $0.name == "auth_token" }
        XCTAssertNotNil(match, "Expected 'auth_token' cookie to be present after save")
        XCTAssertEqual(match?.value, "abc123")
    }

    /// Saving an empty array effectively clears previously stored cookies.
    func test_save_emptyArray_clearsStoredCookies() throws {
        clearStoredCookies()

        let cookie = try XCTUnwrap(makeCookie(name: "session", value: "xyz"))
        CookieManager.save([cookie])

        // Overwrite with empty
        CookieManager.save([])

        let loaded = CookieManager.load()
        // After saving empty, load should return empty (nothing valid to deserialize)
        XCTAssertTrue(loaded.isEmpty, "Expected no cookies after saving empty array")
    }

    /// Saving multiple cookies and loading them all back preserves each entry.
    func test_save_multipleCookes_allRetrieved() throws {
        clearStoredCookies()

        let c1 = try XCTUnwrap(makeCookie(name: "auth_token", value: "tok1"))
        let c2 = try XCTUnwrap(makeCookie(name: "ct0", value: "csrf1"))
        CookieManager.save([c1, c2])

        let loaded = CookieManager.load()

        XCTAssertEqual(loaded.count, 2, "Expected both cookies to be loaded")
        XCTAssertTrue(loaded.contains { $0.name == "auth_token" })
        XCTAssertTrue(loaded.contains { $0.name == "ct0" })
    }
}
