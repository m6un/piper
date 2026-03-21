// XLoginView.swift — WKWebView login sheet (View layer)
// Presents x.com/login and detects successful login by monitoring navigation to x.com/home.
// Never accesses storage directly — delegates all cookie work to CookieManager.

import SwiftUI
import WebKit

/// The result of a login attempt.
enum LoginResult {
    case success
    case cancelled
}

/// A SwiftUI wrapper around a WKWebView that loads x.com/login.
struct XLoginView: View {

    let cookieManager: CookieManager
    let onComplete: (LoginResult) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            XLoginWebView(cookieManager: cookieManager, onComplete: { result in
                onComplete(result)
            })
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Connect X Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(.cancelled)
                    }
                }
            }
        }
    }
}

// MARK: - UIViewRepresentable wrapper

struct XLoginWebView: UIViewRepresentable {

    let cookieManager: CookieManager
    let onComplete: (LoginResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(cookieManager: cookieManager, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        webView.load(context.coordinator.makeInitialRequest())
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        let cookieManager: CookieManager
        let onComplete: (LoginResult) -> Void
        weak var webView: WKWebView?
        private var didRetryFallbackURL = false
        private var hasCompleted = false

        // Start at twitter.com login flow; x.com sometimes fails to render in embedded webviews.
        private let initialLoginURL = URL(string: "https://twitter.com/i/flow/login")!
        private let fallbackLoginURL = URL(string: "https://x.com/i/flow/login")!

        init(cookieManager: CookieManager, onComplete: @escaping (LoginResult) -> Void) {
            self.cookieManager = cookieManager
            self.onComplete = onComplete
        }

        func makeInitialRequest() -> URLRequest {
            URLRequest(url: initialLoginURL)
        }

        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!) {
            guard !hasCompleted else { return }
            guard let url = webView.url else { return }
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore

            // Primary path: URL-based success detection.
            if isLoginSuccess(url: url) {
                completeSuccess(using: cookieStore)
                return
            }

            // Fallback path: detect a valid authenticated session by cookies.
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                guard !self.hasCompleted else { return }
                if self.hasAuthenticatedSessionCookie(cookies) {
                    self.completeSuccess(using: cookieStore)
                }
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Keep non-http(s) navigations from killing the page load.
            if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https" {
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            retryWithFallbackIfNeeded(webView: webView)
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            retryWithFallbackIfNeeded(webView: webView)
        }

        /// Returns `true` when the URL indicates a successful login (landed on x.com/home).
        func isLoginSuccess(url: URL) -> Bool {
            guard let host = url.host else { return false }
            let isXHost = host == "x.com" || host.hasSuffix(".x.com")
            let isTwitterHost = host == "twitter.com" || host.hasSuffix(".twitter.com")
            let isHomePath = url.path == "/home"
            return (isXHost || isTwitterHost) && isHomePath
        }

        private func retryWithFallbackIfNeeded(webView: WKWebView) {
            guard !didRetryFallbackURL else { return }
            didRetryFallbackURL = true
            webView.load(URLRequest(url: fallbackLoginURL))
        }

        private func completeSuccess(using cookieStore: WKHTTPCookieStore) {
            guard !hasCompleted else { return }
            hasCompleted = true
            cookieManager.extractAndSave(from: cookieStore) { [weak self] in
                DispatchQueue.main.async {
                    self?.onComplete(.success)
                }
            }
        }

        private func hasAuthenticatedSessionCookie(_ cookies: [HTTPCookie]) -> Bool {
            let sessionCookieNames: Set<String> = ["auth_token", "twid", "ct0"]
            return cookies.contains { cookie in
                let isNameMatch = sessionCookieNames.contains(cookie.name)
                let isDomainMatch = cookie.domain.hasSuffix(".x.com")
                    || cookie.domain == "x.com"
                    || cookie.domain.hasSuffix(".twitter.com")
                    || cookie.domain == "twitter.com"
                return isNameMatch && isDomainMatch
            }
        }
    }

}
