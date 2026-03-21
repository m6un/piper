// LoginDetectionTests.swift — Tests for login-success URL detection logic.
// Tests the XLoginWebView.Coordinator.isLoginSuccess(url:) pure function
// and the callback firing behaviour for success/cancel flows.

import XCTest
@testable import Piper

final class LoginDetectionTests: XCTestCase {

    // MARK: - Helpers

    private func makeCoordinator(onComplete: @escaping (LoginResult) -> Void) -> XLoginWebView.Coordinator {
        let storage = InMemoryStorage()
        let cookieManager = CookieManager(storage: storage)
        return XLoginWebView.Coordinator(cookieManager: cookieManager, onComplete: onComplete)
    }

    // MARK: - Test 1: Detects successful login (navigation to x.com/home)

    func testDetectsSuccessfulLogin() {
        let coordinator = makeCoordinator { _ in }
        let homeURL = URL(string: "https://x.com/home")!
        XCTAssertTrue(coordinator.isLoginSuccess(url: homeURL))

        let twitterHomeURL = URL(string: "https://twitter.com/home")!
        XCTAssertTrue(coordinator.isLoginSuccess(url: twitterHomeURL))
    }

    // MARK: - Test 2: Ignores intermediate navigations (x.com/login/flow/...)

    func testIgnoresIntermediateNavigations() {
        let coordinator = makeCoordinator { _ in }

        let urls = [
            URL(string: "https://x.com/login")!,
            URL(string: "https://x.com/login/flow/single_sign_on")!,
            URL(string: "https://x.com/i/flow/login")!,
            URL(string: "https://x.com/")!,
        ]
        for url in urls {
            XCTAssertFalse(coordinator.isLoginSuccess(url: url), "Expected false for \(url)")
        }
    }

    // MARK: - Test 3: Detects cancel — callback fires when cancelled

    func testDetectsCancelCallbackFires() {
        var result: LoginResult?
        let coordinator = makeCoordinator { r in result = r }

        // Simulate the cancel button being tapped.
        coordinator.onComplete(.cancelled)

        XCTAssertEqual(result, .cancelled)
    }

    // MARK: - Additional: success callback fires

    func testSuccessCallbackFires() {
        var result: LoginResult?
        let coordinator = makeCoordinator { r in result = r }

        coordinator.onComplete(.success)

        XCTAssertEqual(result, .success)
    }
}

// Make LoginResult Equatable for XCTAssertEqual.
extension LoginResult: Equatable {}
