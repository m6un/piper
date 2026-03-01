import SwiftUI
import WebKit

/// Presents a WKWebView sheet that loads x.com/login.
/// Detects a successful login by watching for a redirect to x.com/home,
/// then passes the cookies to CookieManager and dismisses itself.
/// Storage access is delegated entirely to CookieManager (layer rule compliance).
struct XLoginView: UIViewRepresentable {

    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://x.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               let host = url.host,
               host.contains("x.com"),
               url.path.contains("/home") {
                // Login succeeded — harvest cookies before dismissing
                extractAndSaveCookies(from: webView)
                decisionHandler(.allow)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            guard
                let url = webView.url,
                let host = url.host,
                host.contains("x.com"),
                url.path.contains("/home")
            else { return }

            extractAndSaveCookies(from: webView)
        }

        // MARK: - Private

        private func extractAndSaveCookies(from webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                CookieManager.save(cookies)
                DispatchQueue.main.async {
                    self?.isPresented = false
                }
            }
        }
    }
}

// MARK: - Sheet wrapper

/// Wraps XLoginView in a NavigationStack with a cancel button for ergonomic presentation.
struct XLoginSheet: View {

    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            XLoginView(isPresented: $isPresented)
                .ignoresSafeArea()
                .navigationTitle("Connect X Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}
