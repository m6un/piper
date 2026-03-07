// PiperAPIClientTests.swift — Unit tests for PiperAPIClient (Services layer)
// Uses MockURLSession to avoid real network calls.

import XCTest
@testable import PiperShareExtension

// MARK: - Mock URLSession infrastructure

/// A captured URLRequest so tests can inspect what the client sent.
private var lastCapturedRequest: URLRequest?

/// A mock data task that simply calls back synchronously.
private final class MockDataTask: URLSessionDataTaskProtocol {
    private let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    func resume() { handler() }
}

/// Injectable mock session.
private final class MockURLSession: URLSessionProtocol {
    var stubbedData: Data?
    var stubbedResponse: URLResponse?
    var stubbedError: Error?

    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        lastCapturedRequest = request
        return MockDataTask {
            completionHandler(self.stubbedData, self.stubbedResponse, self.stubbedError)
        }
    }
}

// MARK: - Helpers

private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: Config.backendBaseURL + "/save")!,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil)!
}

// MARK: - Tests

final class PiperAPIClientTests: XCTestCase {

    private var session: MockURLSession!
    private var sut: PiperAPIClient!

    override func setUp() {
        super.setUp()
        session = MockURLSession()
        sut = PiperAPIClient(session: session)
        lastCapturedRequest = nil
    }

    override func tearDown() {
        session = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Test 1: Successful save returns URL

    func testSuccessfulSaveReturnsURL() {
        let responseBody = #"{"url":"https://piper.workers.dev/abc-123"}"#.data(using: .utf8)!
        session.stubbedData = responseBody
        session.stubbedResponse = makeHTTPResponse(statusCode: 200)

        let expectation = expectation(description: "save completes")
        sut.save(title: "Title", content: "<p>Content</p>") { result in
            switch result {
            case .success(let url):
                XCTAssertEqual(url, "https://piper.workers.dev/abc-123")
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 2: Server error (500) throws error with "Failed to save"

    func testServerErrorThrowsError() {
        session.stubbedData = "Internal Server Error".data(using: .utf8)
        session.stubbedResponse = makeHTTPResponse(statusCode: 500)

        let expectation = expectation(description: "save completes")
        sut.save(title: "Title", content: "Content") { result in
            switch result {
            case .success:
                XCTFail("Expected failure for 500 response")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("Failed to save"),
                              "Error message should contain 'Failed to save', got: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 3: Invalid JSON response throws parse error

    func testInvalidJSONResponseThrowsParseError() {
        session.stubbedData = "not json at all".data(using: .utf8)
        session.stubbedResponse = makeHTTPResponse(statusCode: 200)

        let expectation = expectation(description: "save completes")
        sut.save(title: "Title", content: "Content") { result in
            switch result {
            case .success:
                XCTFail("Expected parse failure")
            case .failure(let error):
                // Should be a parse error
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 4: Network timeout throws network error

    func testNetworkTimeoutThrowsError() {
        let timeoutError = NSError(domain: NSURLErrorDomain,
                                   code: NSURLErrorTimedOut,
                                   userInfo: nil)
        session.stubbedError = timeoutError
        session.stubbedResponse = nil

        let expectation = expectation(description: "save completes")
        sut.save(title: "Title", content: "Content") { result in
            switch result {
            case .success:
                XCTFail("Expected timeout error")
            case .failure(let error):
                XCTAssertNotNil(error)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 5: 400 bad request returns error

    func testBadRequestReturnsError() {
        let serverMsg = "title is required"
        session.stubbedData = serverMsg.data(using: .utf8)
        session.stubbedResponse = makeHTTPResponse(statusCode: 400)

        let expectation = expectation(description: "save completes")
        sut.save(title: "", content: "") { result in
            switch result {
            case .success:
                XCTFail("Expected failure for 400")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("Failed to save"),
                              "Got: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Test 6: Request body format is JSON {title, content}

    func testRequestBodyFormat() {
        session.stubbedData = #"{"url":"https://piper.workers.dev/x"}"#.data(using: .utf8)
        session.stubbedResponse = makeHTTPResponse(statusCode: 200)

        let expectation = expectation(description: "save completes")
        sut.save(title: "My Title", content: "<p>My Content</p>") { _ in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)

        // Inspect the captured request body.
        XCTAssertNotNil(lastCapturedRequest?.httpBody, "Request must have a body")
        if let bodyData = lastCapturedRequest?.httpBody,
           let parsed = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(parsed["title"], "My Title")
            XCTAssertEqual(parsed["content"], "<p>My Content</p>")
        } else {
            XCTFail("Request body is not valid JSON with title/content keys")
        }
    }

    // MARK: - Test 7: Request URL uses Config.backendBaseURL

    func testRequestURLUsesConfigConstant() {
        session.stubbedData = #"{"url":"https://piper.workers.dev/x"}"#.data(using: .utf8)
        session.stubbedResponse = makeHTTPResponse(statusCode: 200)

        let expectation = expectation(description: "save completes")
        sut.save(title: "T", content: "C") { _ in expectation.fulfill() }
        waitForExpectations(timeout: 1)

        XCTAssertNotNil(lastCapturedRequest?.url)
        let requestURLString = lastCapturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(requestURLString.hasPrefix(Config.backendBaseURL),
                      "Request URL must start with Config.backendBaseURL. Got: \(requestURLString)")
    }
}
