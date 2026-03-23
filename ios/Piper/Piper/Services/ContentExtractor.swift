// ContentExtractor.swift — Extracts article content from a URL (Services layer)
// Loads a URL in a hidden WKWebView with injected cookies, then runs readability.js
// to pull out {title, content}. Never accessed by Views directly.

import Foundation
import WebKit

// MARK: - Errors

/// Errors that can occur during content extraction.
public enum ContentExtractionError: Error, LocalizedError {
    case readabilityReturnedNull
    case javascriptExecutionFailed(String)
    case unexpectedResultType
    case bundleResourceMissing

    public var errorDescription: String? {
        switch self {
        case .readabilityReturnedNull:
            return "Couldn't extract article — try opening in Safari first"
        case .javascriptExecutionFailed(let detail):
            return "JavaScript error: \(detail)"
        case .unexpectedResultType:
            return "Unexpected result from content extraction"
        case .bundleResourceMissing:
            return "readability.js resource is missing from the app bundle"
        }
    }
}

// MARK: - Protocol (enables mocking in tests)

/// Abstracts content extraction so tests can inject a mock.
public protocol ContentExtracting {
    func extract(from url: URL,
                 cookies: [HTTPCookie],
                 completion: @escaping (Result<ExtractedContent, Error>) -> Void)
}

// MARK: - ContentExtractor

/// Loads a URL in a hidden WKWebView, injects readability.js, and extracts
/// article {title, content}.
///
/// - Cookie injection: cookies are pushed into WKHTTPCookieStore before navigation.
/// - readability.js: bundled as a resource in the Piper app target.
/// - Memory: WKWebView is released as soon as extraction completes.
public final class ContentExtractor: NSObject, ContentExtracting, WKNavigationDelegate {

    // MARK: - Private state

    private var webView: WKWebView?
    private var completion: ((Result<ExtractedContent, Error>) -> Void)?
    private var pendingURL: URL?
    private var pendingCookies: [HTTPCookie] = []
    private var retryCount = 0
    private let bundle: Bundle
    private let maxRetries = 2

    /// Designated initialiser.
    /// - Parameter bundle: The bundle from which readability.js is loaded.
    ///   Defaults to the app's own bundle.
    public init(bundle: Bundle = Bundle(for: ContentExtractor.self)) {
        self.bundle = bundle
        super.init()
    }

    // MARK: - ContentExtracting

    /// Loads `url` with `cookies` injected, then extracts content.
    /// The completion block is always called exactly once on the main thread.
    public func extract(from url: URL,
                        cookies: [HTTPCookie],
                        completion: @escaping (Result<ExtractedContent, Error>) -> Void) {
        // Guard: readability.js must be present.
        guard bundle.url(forResource: "readability", withExtension: "js") != nil else {
            DispatchQueue.main.async { completion(.failure(ContentExtractionError.bundleResourceMissing)) }
            return
        }

        self.completion = completion
        self.pendingURL = url
        self.pendingCookies = cookies
        self.retryCount = 0

        // Create a fresh WKWebView configuration using the default persistent data store.
        // A non-persistent store causes sandbox-extension failures on real devices,
        // killing the web-content process before navigation completes.
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        // Inject cookies before loading the page.
        let cookieStore = config.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self, let url = self.pendingURL else { return }
            self.webView?.load(URLRequest(url: url))
        }
    }

    // MARK: - WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectReadabilityAndExtract(webView: webView)
    }

    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Block non-HTTP(S) navigations (e.g. twitter://) to prevent frame-load interruptions.
        if let scheme = navigationAction.request.url?.scheme?.lowercased(),
           scheme != "http", scheme != "https" {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView,
                        didFail navigation: WKNavigation!,
                        withError error: Error) {
        handleNavigationFailure(error: error)
    }

    public func webView(_ webView: WKWebView,
                        didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: Error) {
        handleNavigationFailure(error: error)
    }

    // MARK: - Private

    private func injectReadabilityAndExtract(webView: WKWebView) {
        // Load readability.js source from bundle.
        guard let jsURL = bundle.url(forResource: "readability", withExtension: "js"),
              let jsSource = try? String(contentsOf: jsURL, encoding: .utf8) else {
            finish(with: .failure(ContentExtractionError.bundleResourceMissing))
            return
        }

        // Build a script that injects Readability, runs parse(), and returns JSON.
        let extractionScript = """
        (function() {
            \(jsSource)
            try {
                var article = new Readability(document).parse();
                if (!article) { return JSON.stringify({error: "null"}); }
                return JSON.stringify({title: article.title || "", content: article.content || ""});
            } catch(e) {
                return JSON.stringify({error: e.toString()});
            }
        })();
        """

        webView.evaluateJavaScript(extractionScript) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.finish(with: .failure(ContentExtractionError.javascriptExecutionFailed(error.localizedDescription)))
                return
            }

            guard let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8) else {
                self.finish(with: .failure(ContentExtractionError.unexpectedResultType))
                return
            }

            do {
                let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String]
                if let errorMsg = parsed?["error"] {
                    if errorMsg == "null" {
                        self.finish(with: .failure(ContentExtractionError.readabilityReturnedNull))
                    } else {
                        self.finish(with: .failure(ContentExtractionError.javascriptExecutionFailed(errorMsg)))
                    }
                    return
                }
                let title = parsed?["title"] ?? ""
                let content = parsed?["content"] ?? ""
                self.finish(with: .success(ExtractedContent(title: title, content: content)))
            } catch {
                self.finish(with: .failure(error))
            }
        }
    }

    /// Calls the completion handler once and tears down the WKWebView.
    private func finish(with result: Result<ExtractedContent, Error>) {
        let block = completion
        completion = nil
        webView?.navigationDelegate = nil
        webView = nil
        DispatchQueue.main.async { block?(result) }
    }

    private func handleNavigationFailure(error: Error) {
        if shouldRetryForFrameLoadInterruption(error: error), retryCount < maxRetries {
            retryCount += 1
            retryLoadAfterInterruption()
            return
        }
        finish(with: .failure(error))
    }

    private func shouldRetryForFrameLoadInterruption(error: Error) -> Bool {
        let nsError = error as NSError
        // WebKitErrorFrameLoadInterruptedByPolicyChange = 102
        return nsError.domain == "WebKitErrorDomain"
            && nsError.code == 102
    }

    private func retryLoadAfterInterruption() {
        guard let currentURL = pendingURL else { return }
        let retryURL = (retryCount == 1) ? currentURL : swappedXTwitterHost(url: currentURL)
        pendingURL = retryURL
        webView?.load(URLRequest(url: retryURL))
    }

    private func swappedXTwitterHost(url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return url
        }

        if host == "x.com" || host.hasSuffix(".x.com") {
            components.host = host.replacingOccurrences(of: ".x.com", with: ".twitter.com")
                .replacingOccurrences(of: "x.com", with: "twitter.com")
            return components.url ?? url
        }

        if host == "twitter.com" || host.hasSuffix(".twitter.com") {
            components.host = host.replacingOccurrences(of: ".twitter.com", with: ".x.com")
                .replacingOccurrences(of: "twitter.com", with: "x.com")
            return components.url ?? url
        }

        return url
    }
}
