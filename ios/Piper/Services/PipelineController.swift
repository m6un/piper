// PipelineController.swift — Orchestrates the full pipe flow (Services layer)
// cookies → validate URL → extract content → save to backend → return UUID URL
// Protocol-based dependencies for testability. No UI dependencies.

import Foundation
import WebKit

// MARK: - PipelineError

/// Errors that can occur during the pipeline flow.
public enum PipelineError: Error, LocalizedError {
    case notLoggedIn
    case invalidURL
    case extractionFailed(String)
    case saveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Connect your X account first"
        case .invalidURL:
            return "Copy an article URL from X first"
        case .extractionFailed(let detail):
            return "Extraction failed: \(detail)"
        case .saveFailed(let detail):
            return "Save failed: \(detail)"
        }
    }
}

// MARK: - CookieProviding protocol

/// Abstracts cookie access for the pipeline so CookieManager can be mocked in tests.
public protocol CookieProviding {
    var hasCookies: Bool { get }
    func loadCookies() -> [HTTPCookie]
}

extension CookieManager: CookieProviding {}

// MARK: - PipelineController

/// Orchestrates the full article-pipe flow.
///
/// Usage:
/// ```swift
/// let controller = PipelineController()
/// Task {
///     do {
///         let url = try await controller.pipe(urlString: clipboardString)
///         // url is the UUID URL — copy to clipboard and show success
///     } catch {
///         // show error.localizedDescription
///     }
/// }
/// ```
public final class PipelineController {

    // MARK: - Dependencies

    private let cookieProvider: CookieProviding
    private let extractor: ContentExtracting
    private let apiClient: PiperAPIClientProtocol

    // MARK: - Init

    /// Production initialiser — uses real services.
    public convenience init() {
        self.init(
            cookieProvider: CookieManager(),
            extractor: ContentExtractor(),
            apiClient: PiperAPIClient()
        )
    }

    /// Testable initialiser — inject mocks.
    public init(cookieProvider: CookieProviding,
                extractor: ContentExtracting,
                apiClient: PiperAPIClientProtocol) {
        self.cookieProvider = cookieProvider
        self.extractor = extractor
        self.apiClient = apiClient
    }

    // MARK: - Public API

    /// Runs the full pipe flow for the given URL string.
    ///
    /// - Parameter urlString: A raw URL string (e.g. from UIPasteboard).
    /// - Returns: The UUID URL string returned by the backend.
    /// - Throws: `PipelineError` on any failure — never fails silently.
    public func pipe(urlString: String) async throws -> String {
        // Step 1: Validate cookies — must be logged in.
        guard cookieProvider.hasCookies else {
            throw PipelineError.notLoggedIn
        }

        // Step 2: Validate URL — must be parseable.
        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            throw PipelineError.invalidURL
        }

        let cookies = cookieProvider.loadCookies()

        // Step 3: Extract content.
        let extracted: ExtractedContent = try await withCheckedThrowingContinuation { continuation in
            extractor.extract(from: url, cookies: cookies) { result in
                switch result {
                case .success(let content):
                    continuation.resume(returning: content)
                case .failure(let error):
                    continuation.resume(throwing: PipelineError.extractionFailed(error.localizedDescription))
                }
            }
        }

        // Step 4: Save to backend.
        let resultURL: String = try await withCheckedThrowingContinuation { continuation in
            apiClient.save(title: extracted.title, content: extracted.content) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: PipelineError.saveFailed(error.localizedDescription))
                }
            }
        }

        return resultURL
    }
}
