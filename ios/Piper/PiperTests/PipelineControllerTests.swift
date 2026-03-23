// PipelineControllerTests.swift — Unit tests for PipelineController (Services layer)
// All 5 spec test cases. Uses mock implementations of CookieProviding,
// ContentExtracting, and PiperAPIClientProtocol — no network, no storage.

import XCTest
import WebKit
@testable import Piper

// MARK: - Mock CookieProvider

private final class MockCookieProvider: CookieProviding {
    var hasCookies: Bool
    var cookies: [HTTPCookie]

    init(hasCookies: Bool = true, cookies: [HTTPCookie] = []) {
        self.hasCookies = hasCookies
        self.cookies = cookies
    }

    func loadCookies() -> [HTTPCookie] { cookies }
}

// MARK: - Mock ContentExtractor

private final class MockExtractor: ContentExtracting {
    var result: Result<ExtractedContent, Error>

    init(result: Result<ExtractedContent, Error> = .success(ExtractedContent(title: "T", content: "C"))) {
        self.result = result
    }

    func extract(from url: URL,
                 cookies: [HTTPCookie],
                 completion: @escaping (Result<ExtractedContent, Error>) -> Void) {
        DispatchQueue.main.async { completion(self.result) }
    }
}

// MARK: - Mock API Client

private final class MockAPIClient: PiperAPIClientProtocol {
    var result: Result<String, Error>

    init(result: Result<String, Error> = .success("https://piper.workers.dev/test-uuid")) {
        self.result = result
    }

    func save(title: String,
              content: String,
              completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.main.async { completion(self.result) }
    }
}

// MARK: - Tests

@MainActor
final class PipelineControllerTests: XCTestCase {

    private let validURL = "https://x.com/some/article"

    // MARK: - Test 1: No cookies — returns notLoggedIn error

    func testNoCookiesReturnsNotLoggedIn() async {
        let provider = MockCookieProvider(hasCookies: false)
        let sut = PipelineController(
            cookieProvider: provider,
            extractor: MockExtractor(),
            apiClient: MockAPIClient()
        )

        do {
            _ = try await sut.pipe(urlString: validURL)
            XCTFail("Expected notLoggedIn error but got success")
        } catch let error as PipelineError {
            guard case .notLoggedIn = error else {
                XCTFail("Expected .notLoggedIn, got \(error)")
                return
            }
            // Correct — also verify the message matches the spec.
            XCTAssertEqual(error.localizedDescription, "Connect your X account first")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test 2: Happy path — valid cookies + mock extractor + mock API → success URL

    func testHappyPathReturnsURL() async {
        let provider = MockCookieProvider(hasCookies: true)
        let expectedURL = "https://piper.workers.dev/abc-def-123"
        let sut = PipelineController(
            cookieProvider: provider,
            extractor: MockExtractor(result: .success(ExtractedContent(title: "Article Title", content: "<p>Body</p>"))),
            apiClient: MockAPIClient(result: .success(expectedURL))
        )

        do {
            let resultURL = try await sut.pipe(urlString: validURL)
            XCTAssertEqual(resultURL, expectedURL)
        } catch {
            XCTFail("Expected success, got error: \(error)")
        }
    }

    // MARK: - Test 3: Extraction failure — returns extractionFailed error

    func testExtractionFailureReturnsExtractionError() async {
        let provider = MockCookieProvider(hasCookies: true)
        let extractionError = ContentExtractionError.readabilityReturnedNull
        let sut = PipelineController(
            cookieProvider: provider,
            extractor: MockExtractor(result: .failure(extractionError)),
            apiClient: MockAPIClient()
        )

        do {
            _ = try await sut.pipe(urlString: validURL)
            XCTFail("Expected extractionFailed error but got success")
        } catch let error as PipelineError {
            guard case .extractionFailed(let detail) = error else {
                XCTFail("Expected .extractionFailed, got \(error)")
                return
            }
            XCTAssertFalse(detail.isEmpty, "Extraction error detail must not be empty")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test 4: API failure — extraction succeeds, save fails → saveFailed error

    func testAPIFailureReturnsSaveError() async {
        let provider = MockCookieProvider(hasCookies: true)
        let apiError = PiperAPIError.httpError(statusCode: 500, message: "internal server error")
        let sut = PipelineController(
            cookieProvider: provider,
            extractor: MockExtractor(result: .success(ExtractedContent(title: "T", content: "C"))),
            apiClient: MockAPIClient(result: .failure(apiError))
        )

        do {
            _ = try await sut.pipe(urlString: validURL)
            XCTFail("Expected saveFailed error but got success")
        } catch let error as PipelineError {
            guard case .saveFailed(let detail) = error else {
                XCTFail("Expected .saveFailed, got \(error)")
                return
            }
            XCTAssertFalse(detail.isEmpty, "Save error detail must not be empty")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Test 5: Invalid URL — returns invalidURL error

    func testInvalidURLReturnsInvalidURLError() async {
        let provider = MockCookieProvider(hasCookies: true)
        let sut = PipelineController(
            cookieProvider: provider,
            extractor: MockExtractor(),
            apiClient: MockAPIClient()
        )

        let malformedURLs = ["", "not a url", "   ", "javascript:alert(1)"]

        for urlString in malformedURLs {
            do {
                _ = try await sut.pipe(urlString: urlString)
                XCTFail("Expected invalidURL error for '\(urlString)' but got success")
            } catch let error as PipelineError {
                guard case .invalidURL = error else {
                    XCTFail("Expected .invalidURL for '\(urlString)', got \(error)")
                    continue
                }
                XCTAssertEqual(error.localizedDescription, "Copy an article URL from X first")
            } catch {
                XCTFail("Unexpected error type for '\(urlString)': \(error)")
            }
        }
    }
}
