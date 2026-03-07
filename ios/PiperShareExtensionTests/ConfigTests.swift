// ConfigTests.swift — Tests for Config constants (Models layer)
// Verifies that Config.backendBaseURL is a valid, well-formed URL.

import XCTest
@testable import PiperShareExtension

final class ConfigTests: XCTestCase {

    // MARK: - Test 1: Backend URL is valid

    func testBackendURLIsValid() {
        let urlString = Config.backendBaseURL
        let url = URL(string: urlString)
        XCTAssertNotNil(url, "Config.backendBaseURL must be a parseable URL")
        XCTAssertTrue(urlString.hasPrefix("https://"),
                      "Config.backendBaseURL must start with https://")
    }

    // MARK: - Test 2: Backend URL has no trailing slash

    func testBackendURLHasNoTrailingSlash() {
        XCTAssertFalse(Config.backendBaseURL.hasSuffix("/"),
                       "Config.backendBaseURL must not end with a trailing slash")
    }
}
