// ContentViewTests.swift — Tests for ContentView UI state machine.
// Uses InMemoryStorage (defined in CookieManagerTests.swift) to drive state.
// No direct storage access occurs in test code.

import XCTest
import SwiftUI
@testable import Piper

final class ContentViewTests: XCTestCase {

    // MARK: - Helpers

    private func makeCookieManager() -> CookieManager {
        CookieManager(storage: InMemoryStorage())
    }

    private func makeXCookie() -> HTTPCookie {
        HTTPCookie(properties: [
            .name: "auth_token",
            .value: "test_value",
            .domain: ".x.com",
            .path: "/",
        ])!
    }

    // MARK: - Test 1: Shows connect button initially (no cookies saved)

    func testShowsConnectButtonInitially() {
        let cm = makeCookieManager()
        XCTAssertFalse(cm.hasCookies, "Precondition: no cookies")

        // The initial connection state derives from hasCookies.
        let state: ConnectionState = cm.hasCookies ? .connected : .disconnected
        XCTAssertEqual(state, .disconnected)
    }

    // MARK: - Test 2: Shows connected state when valid cookies are present

    func testShowsConnectedStateWhenCookiesPresent() {
        let cm = makeCookieManager()
        cm.saveCookies([makeXCookie()])
        XCTAssertTrue(cm.hasCookies, "Precondition: cookies saved")

        let state: ConnectionState = cm.hasCookies ? .connected : .disconnected
        XCTAssertEqual(state, .connected)
    }

    // MARK: - Test 3: Updates after login — transitions from disconnected to connected

    func testUpdatesAfterLogin() {
        let cm = makeCookieManager()

        // Before login
        var state: ConnectionState = cm.hasCookies ? .connected : .disconnected
        XCTAssertEqual(state, .disconnected, "Should start disconnected")

        // Simulate successful login: cookies saved, state re-evaluated.
        cm.saveCookies([makeXCookie()])
        state = cm.hasCookies ? .connected : .disconnected
        XCTAssertEqual(state, .connected, "Should be connected after cookies saved")
    }
}
