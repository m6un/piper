// PipeView.swift — Sheet UI for the "Pipe Article" flow (View layer)
// Reads a URL from UIPasteboard, calls PipelineController, shows result or error.
// Views must not access network or storage directly — all routed through PipelineController.

import SwiftUI
import UIKit

// MARK: - PipeState

/// The UI state of the pipe operation.
private enum PipeState: Equatable {
    case idle
    case extracting(URL, [HTTPCookie])
    case saving
    case success(String)   // the UUID URL
    case failure(String)   // the error message
}

// MARK: - PipeView

struct PipeView: View {

    // MARK: - Dependencies (injected)

    let pipeline: PipelineController

    // MARK: - Dismiss

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var pipeState: PipeState = .idle

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentForState
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Pipe Article")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityIdentifier("pipeDoneButton")
                    }
                }
        }
        .onAppear { startPipe() }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForState: some View {
        switch pipeState {
        case .extracting(let url, let cookies):
            // WKWebView is the primary content — must be rendered for iOS to
            // grant process assertions on real devices. Matches XLoginView pattern.
            ExtractionWebView(
                url: url,
                cookies: cookies,
                bundle: Bundle(for: ContentExtractor.self),
                onResult: { result in handleExtractionResult(result) }
            )
            .overlay {
                progressOverlay(text: "Piping article…")
            }

        case .idle:
            progressOverlay(text: "Preparing…")

        case .saving:
            progressOverlay(text: "Saving…")

        case .success(let url):
            successContent(url: url)

        case .failure(let message):
            failureContent(message: message)
        }
    }

    // MARK: - State Views

    private func progressOverlay(text: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .accessibilityIdentifier("pipeActivityIndicator")
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("pipeStatusLabel")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func successContent(url: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("Saved — paste into Instapaper")
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("pipeSuccessLabel")

            Text(url)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func failureContent(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .accessibilityIdentifier("pipeErrorLabel")

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Pipeline

    private func startPipe() {
        let clipboardString = UIPasteboard.general.string ?? ""

        guard !clipboardString.isEmpty, URL(string: clipboardString) != nil else {
            pipeState = .failure("Copy an article URL from X first")
            return
        }

        do {
            let (url, cookies) = try pipeline.validate(urlString: clipboardString)
            pipeState = .extracting(url, cookies)
        } catch {
            pipeState = .failure(error.localizedDescription)
        }
    }

    private func handleExtractionResult(_ result: Result<ExtractedContent, Error>) {
        switch result {
        case .success(let extracted):
            pipeState = .saving
            Task {
                do {
                    let resultURL = try await pipeline.save(
                        title: extracted.title,
                        content: extracted.content
                    )
                    await MainActor.run {
                        UIPasteboard.general.string = resultURL
                        pipeState = .success(resultURL)
                    }
                } catch {
                    await MainActor.run {
                        pipeState = .failure(error.localizedDescription)
                    }
                }
            }
        case .failure(let error):
            pipeState = .failure(error.localizedDescription)
        }
    }
}
