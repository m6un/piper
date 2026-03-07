// ShareViewController.swift — Share Extension entry point (View layer)
// Orchestrates the full share flow: read cookies → load page → extract → POST → clipboard.
// Never touches network or persistent storage directly — all routed through Services.

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

// MARK: - ShareViewController

/// The root view controller for the PiperShareExtension.
///
/// Lifecycle:
///   1. viewDidLoad: validate cookies, extract URL from share context.
///   2. If either is missing, show error and exit.
///   3. Otherwise: show progress, kick off extraction → POST → clipboard → show success.
///
/// Layer rules: this file must never import WebKit directly (WKWebView is
/// encapsulated in ContentExtractor), must never call URLSession, and must
/// never access cookie or key-value storage directly.
open class ShareViewController: UIViewController {

    // MARK: - Dependency injection
    //
    // Non-private so tests can substitute mocks before viewDidLoad.

    var cookieManager: CookieManager = CookieManager()
    var contentExtractor: ContentExtracting = ContentExtractor()
    var apiClient: PiperAPIClientProtocol = PiperAPIClient()
    var pasteboard: UIPasteboardProtocol = UIPasteboard.general

    // MARK: - UI

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "statusLabel"
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.accessibilityIdentifier = "activityIndicator"
        return indicator
    }()

    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "doneButton"
        return button
    }()

    // MARK: - Lifecycle

    override open func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startFlow()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -24),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            doneButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        doneButton.addTarget(self, action: #selector(dismissExtension), for: .touchUpInside)
    }

    // MARK: - Flow

    private func startFlow() {
        // Step 1: Validate cookies.
        guard cookieManager.hasCookies else {
            showError("Open Piper to connect your X account")
            return
        }

        // Step 2: Extract URL from share context.
        extractSharedURL { [weak self] url in
            guard let self = self else { return }
            guard let url = url else {
                self.showError("No URL found in share input")
                return
            }
            self.runExtraction(url: url)
        }
    }

    private func runExtraction(url: URL) {
        showProgress("Loading article…")
        let cookies = cookieManager.loadCookies()
        contentExtractor.extract(from: url, cookies: cookies) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let extracted):
                self.runSave(extracted: extracted)
            case .failure(let error):
                self.showError(error.localizedDescription)
            }
        }
    }

    private func runSave(extracted: ExtractedContent) {
        showProgress("Saving…")
        apiClient.save(title: extracted.title, content: extracted.content) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let urlString):
                    self.pasteboard.string = urlString
                    self.showSuccess("Saved — paste into Instapaper")
                case .failure(let error):
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - URL Extraction from NSExtensionContext

    /// Pulls the first URL out of the extension context's input items.
    func extractSharedURL(completion: @escaping (URL?) -> Void) {
        guard let extensionContext = extensionContext else {
            completion(nil)
            return
        }

        let items = extensionContext.inputItems as? [NSExtensionItem] ?? []
        for item in items {
            for provider in (item.attachments ?? []) {
                // iOS 14+ identifier
                let urlType: String
                if #available(iOS 14.0, *) {
                    urlType = UTType.url.identifier
                } else {
                    urlType = kUTTypeURL as String
                }

                if provider.hasItemConformingToTypeIdentifier(urlType) {
                    provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, _ in
                        DispatchQueue.main.async {
                            if let url = item as? URL {
                                completion(url)
                            } else if let string = item as? String, let url = URL(string: string) {
                                completion(url)
                            } else {
                                completion(nil)
                            }
                        }
                    }
                    return
                }
            }
        }
        DispatchQueue.main.async { completion(nil) }
    }

    // MARK: - State Presentation

    /// Shows a working/in-progress indicator with a message.
    func showProgress(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            self.statusLabel.textColor = .label
            self.activityIndicator.startAnimating()
            self.doneButton.isHidden = true
        }
    }

    /// Shows a success state with a message and a Done button.
    func showSuccess(_ message: String) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.statusLabel.text = message
            self.statusLabel.textColor = .systemGreen
            self.doneButton.isHidden = false
        }
    }

    /// Shows an error state with a message and a Done button.
    func showError(_ message: String) {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.statusLabel.text = message
            self.statusLabel.textColor = .systemRed
            self.doneButton.isHidden = false
        }
    }

    // MARK: - Dismiss

    @objc private func dismissExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - UIPasteboardProtocol

/// Abstraction over UIPasteboard so tests can inject a mock without touching the system clipboard.
public protocol UIPasteboardProtocol: AnyObject {
    var string: String? { get set }
}

extension UIPasteboard: UIPasteboardProtocol {}
