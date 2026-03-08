// PipeView.swift — Sheet UI for the "Pipe Article" flow (View layer)
// Reads a URL from UIPasteboard, calls PipelineController, shows result or error.
// Views must not access network or storage directly — all routed through PipelineController.

import SwiftUI
import UIKit

// MARK: - PipeState

/// The UI state of the pipe operation.
private enum PipeState: Equatable {
    case idle
    case running
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
        VStack(spacing: 24) {
            Spacer()

            switch pipeState {
            case .idle:
                idleContent

            case .running:
                runningContent

            case .success(let url):
                successContent(url: url)

            case .failure(let message):
                failureContent(message: message)
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
                .accessibilityIdentifier("pipeDoneButton")
        }
        .padding(.horizontal, 32)
        .onAppear { startPipe() }
    }

    // MARK: - State Views

    private var idleContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .accessibilityIdentifier("pipeActivityIndicator")
            Text("Preparing…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var runningContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .accessibilityIdentifier("pipeActivityIndicator")
            Text("Piping article…")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("pipeStatusLabel")
        }
    }

    private func successContent(url: String) -> some View {
        VStack(spacing: 16) {
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
        }
    }

    private func failureContent(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .accessibilityIdentifier("pipeErrorLabel")
        }
    }

    // MARK: - Pipeline

    private func startPipe() {
        // Read URL from clipboard.
        let clipboardString = UIPasteboard.general.string ?? ""

        guard !clipboardString.isEmpty, URL(string: clipboardString) != nil else {
            pipeState = .failure("Copy an article URL from X first")
            return
        }

        pipeState = .running

        Task {
            do {
                let resultURL = try await pipeline.pipe(urlString: clipboardString)
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
    }
}
