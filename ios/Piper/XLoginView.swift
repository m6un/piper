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

        if let url = URL(string: "https://x.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        let cookieManager: CookieManager
        let onComplete: (LoginResult) -> Void
        weak var webView: WKWebView?

        init(cookieManager: CookieManager, onComplete: @escaping (LoginResult) -> Void) {
            self.cookieManager = cookieManager
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView,
                     didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            guard isLoginSuccess(url: url) else { return }

            // Extract cookies and persist them, then report success.
            cookieManager.extractAndSave(from: webView.configuration.websiteDataStore.httpCookieStore) {
                DispatchQueue.main.async { [weak self] in
                    self?.onComplete(.success)
                }
            }
        }

        /// Returns `true` when the URL indicates a successful login (landed on x.com/home).
        func isLoginSuccess(url: URL) -> Bool {
            guard let host = url.host else { return false }
            let isXHost = host == "x.com" || host.hasSuffix(".x.com")
            let isHomePath = url.path == "/home"
            return isXHost && isHomePath
        }
    }
}
