// ExtractionWebView.swift — UIViewRepresentable for content extraction (View layer)
// Hosts a WKWebView in the view hierarchy so iOS grants process assertions.
// Injects cookies, loads the target URL, runs readability.js, and returns ExtractedContent.

import SwiftUI
import WebKit

/// UIViewRepresentable that extracts article content from a URL.
/// Must be the primary rendered content (not hidden or zero-sized) for iOS to grant
/// WKWebView process assertions on real devices.
struct ExtractionWebView: UIViewRepresentable {

    let url: URL
    let cookies: [HTTPCookie]
    let bundle: Bundle
    let onResult: (Result<ExtractedContent, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, cookies: cookies, bundle: bundle, onResult: onResult)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Request desktop content mode to prevent X.com from redirecting to
        // twitter:// deep links, which WKWebView can't load (error 102).
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.preferredContentMode = .desktop
        config.defaultWebpagePreferences = pagePrefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // Desktop Safari UA — X.com serves web content instead of app redirects.
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        // Inject cookies before loading.
        let cookieStore = config.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        private let url: URL
        private let cookies: [HTTPCookie]
        private let bundle: Bundle
        private let onResult: (Result<ExtractedContent, Error>) -> Void
        private var hasCompleted = false
        private var retryCount = 0
        private let maxRetries = 2
        private var extractionAttempts = 0
        private let maxExtractionAttempts = 5

        init(url: URL, cookies: [HTTPCookie], bundle: Bundle,
             onResult: @escaping (Result<ExtractedContent, Error>) -> Void) {
            self.url = url
            self.cookies = cookies
            self.bundle = bundle
            self.onResult = onResult
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasCompleted else { return }
            // X.com is a React SPA — content renders via JS after didFinish.
            // Wait for the SPA to hydrate before running readability.js.
            scheduleExtraction(webView: webView, delay: 2.0)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(ContentExtractor.navigationPolicy(for: navigationAction.request.url))
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(webView: webView, error: error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(webView: webView, error: error)
        }

        // MARK: - Private

        private func handleFailure(webView: WKWebView, error: Error) {
            guard !hasCompleted else { return }
            let nsError = error as NSError
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 && retryCount < maxRetries {
                retryCount += 1
                webView.load(URLRequest(url: url))
                return
            }
            finish(.failure(error))
        }

        private func scheduleExtraction(webView: WKWebView, delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, !self.hasCompleted else { return }
                self.extractionAttempts += 1
                self.injectReadabilityAndExtract(webView: webView)
            }
        }

        private func injectReadabilityAndExtract(webView: WKWebView) {
            guard let jsURL = bundle.url(forResource: "readability", withExtension: "js"),
                  let jsSource = try? String(contentsOf: jsURL, encoding: .utf8) else {
                finish(.failure(ContentExtractionError.bundleResourceMissing))
                return
            }

            let script = """
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

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self, !self.hasCompleted else { return }

                if let error {
                    self.finish(.failure(ContentExtractionError.javascriptExecutionFailed(error.localizedDescription)))
                    return
                }

                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8) else {
                    self.finish(.failure(ContentExtractionError.unexpectedResultType))
                    return
                }

                do {
                    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: String]
                    if let errorMsg = parsed?["error"] {
                        if errorMsg == "null" {
                            // SPA might not have rendered yet — retry
                            if self.extractionAttempts < self.maxExtractionAttempts {
                                self.scheduleExtraction(webView: webView, delay: 1.5)
                                return
                            }
                            self.finish(.failure(ContentExtractionError.readabilityReturnedNull))
                        } else {
                            self.finish(.failure(ContentExtractionError.javascriptExecutionFailed(errorMsg)))
                        }
                        return
                    }
                    let title = parsed?["title"] ?? ""
                    let content = parsed?["content"] ?? ""

                    // If content is thin and title is empty, SPA probably hasn't
                    // rendered yet — retry before accepting.
                    if title.isEmpty && content.count < 500 && self.extractionAttempts < self.maxExtractionAttempts {
                        self.scheduleExtraction(webView: webView, delay: 1.5)
                        return
                    }

                    self.finish(.success(ExtractedContent(title: title, content: content)))
                } catch {
                    self.finish(.failure(error))
                }
            }
        }

        private func finish(_ result: Result<ExtractedContent, Error>) {
            guard !hasCompleted else { return }
            hasCompleted = true
            DispatchQueue.main.async { self.onResult(result) }
        }
    }
}
