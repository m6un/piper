// ContentView.swift — Main app screen (View layer)
// Displays connect/connected state. Never accesses network or storage directly.

import SwiftUI

struct ContentView: View {

    // MARK: - Dependencies (injected)

    let cookieManager: CookieManager
    let pipeline: PipelineController

    // MARK: - State

    @State private var connectionState: ConnectionState
    @State private var showingLoginSheet = false
    @State private var showingPipeSheet = false

    // MARK: - Init

    init(cookieManager: CookieManager, pipeline: PipelineController) {
        self.cookieManager = cookieManager
        self.pipeline = pipeline
        _connectionState = State(initialValue: cookieManager.hasCookies ? .connected : .disconnected)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bird")
                .font(.system(size: 64))
                .foregroundColor(.primary)

            Text("Piper")
                .font(.largeTitle.bold())

            Text("Save X articles to Instapaper — copy a URL, tap Pipe Article.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            switch connectionState {
            case .disconnected:
                Button(action: { showingLoginSheet = true }) {
                    Label("Connect X Account", systemImage: "person.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .accessibilityIdentifier("connectButton")

            case .connected:
                VStack(spacing: 16) {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                        .accessibilityIdentifier("connectedLabel")

                    Button(action: { showingPipeSheet = true }) {
                        Label("Pipe Article", systemImage: "arrow.up.doc")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier("pipeButton")

                    Button("Disconnect", role: .destructive) {
                        cookieManager.clearCookies()
                        connectionState = .disconnected
                    }
                    .font(.footnote)
                    .accessibilityIdentifier("disconnectButton")
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showingLoginSheet) {
            XLoginView(cookieManager: cookieManager) { result in
                showingLoginSheet = false
                switch result {
                case .success:
                    connectionState = .connected
                case .cancelled:
                    // Stay on connect screen — no silent failure (Belief #6)
                    break
                }
            }
        }
        .sheet(isPresented: $showingPipeSheet) {
            PipeView(pipeline: pipeline)
        }
    }
}
