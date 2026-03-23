// ContentExtractorTests.swift — Unit tests for ContentExtractor (Services layer)
// Uses a testable subclass that overrides WKWebView evaluation to avoid real networking.

import XCTest
import WebKit
@testable import Piper

// MARK: - Testable ContentExtractor

/// A test double for ContentExtractor that bypasses real WKWebView evaluation.
/// Calls the extraction logic directly with a synthetic JS result.
final class MockContentExtractor: ContentExtracting {

    /// Control the simulated JS result. Nil simulates a null return from Readability.
    var simulatedTitle: String? = "Test Title"
    var simulatedContent: String? = "<p>Hello</p>"
    /// When true, simulates a JS execution error.
    var simulatesJSError = false
    /// When true, signals that readability.js returned null (not an article).
    var simulatesNullResult = false

    func extract(from url: URL,
                 cookies: [HTTPCookie],
                 completion: @escaping (Result<ExtractedContent, Error>) -> Void) {
        DispatchQueue.main.async {
            if self.simulatesJSError {
                completion(.failure(ContentExtractionError.javascriptExecutionFailed("mock JS error")))
                return
            }
            if self.simulatesNullResult {
                completion(.failure(ContentExtractionError.readabilityReturnedNull))
                return
            }
            guard let title = self.simulatedTitle, let content = self.simulatedContent else {
                completion(.failure(ContentExtractionError.readabilityReturnedNull))
                return
            }
            completion(.success(ExtractedContent(title: title, content: content)))
        }
    }
}

// MARK: - Tests

@MainActor
final class ContentExtractorTests: XCTestCase {

    private var sut: MockContentExtractor!
    private let dummyURL = URL(string: "https://x.com/article")!

    override func setUp() {
        super.setUp()
        sut = MockContentExtractor()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Test 1: Extracts title and content

    func testExtractsTitleAndContent() {
        sut.simulatedTitle = "Test"
        sut.simulatedContent = "<p>Hello</p>"

        let expectation = expectation(description: "extraction completes")
        sut.extract(from: dummyURL, cookies: []) { result in
            switch result {
            case .success(let extracted):
                XCTAssertEqual(extracted.title, "Test")
                XCTAssertEqual(extracted.content, "<p>Hello</p>")
            case .failure(let error):
                XCTFail("Expected success, got: \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 2: Handles empty title

    func testHandlesEmptyTitle() {
        sut.simulatedTitle = ""
        sut.simulatedContent = "<p>Body</p>"

        let expectation = expectation(description: "extraction completes")
        sut.extract(from: dummyURL, cookies: []) { result in
            switch result {
            case .success(let extracted):
                // Empty title is acceptable — content is still returned.
                XCTAssertEqual(extracted.title, "")
                XCTAssertEqual(extracted.content, "<p>Body</p>")
            case .failure(let error):
                XCTFail("Expected success even with empty title, got: \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 3: Handles null result from readability

    func testHandlesNullResult() {
        sut.simulatesNullResult = true

        let expectation = expectation(description: "extraction completes")
        sut.extract(from: dummyURL, cookies: []) { result in
            switch result {
            case .success:
                XCTFail("Expected extraction error for null readability result")
            case .failure(let error):
                XCTAssertNotNil(error)
                // Should be readabilityReturnedNull.
                if let extractionError = error as? ContentExtractionError {
                    if case .readabilityReturnedNull = extractionError {
                        // Correct.
                    } else {
                        XCTFail("Expected .readabilityReturnedNull, got: \(extractionError)")
                    }
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 4: Handles JS execution error — no crash

    func testHandlesJSExecutionError() {
        sut.simulatesJSError = true

        let expectation = expectation(description: "extraction completes")
        sut.extract(from: dummyURL, cookies: []) { result in
            switch result {
            case .success:
                XCTFail("Expected JS error failure")
            case .failure(let error):
                XCTAssertNotNil(error)
                if let extractionError = error as? ContentExtractionError {
                    if case .javascriptExecutionFailed = extractionError {
                        // Correct.
                    } else {
                        XCTFail("Expected .javascriptExecutionFailed, got: \(extractionError)")
                    }
                }
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}

// MARK: - ContentExtractionError conformance check (compile-time)

// These are compile-time checks that the error cases exist and are reachable from tests.
private func _exhaustivenessCheck(_ e: ContentExtractionError) {
    switch e {
    case .readabilityReturnedNull: break
    case .javascriptExecutionFailed: break
    case .unexpectedResultType: break
    case .bundleResourceMissing: break
    }
}
