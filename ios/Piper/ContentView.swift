import SwiftUI

/// The sole screen of the main Piper app.
/// Explains the product and lets the user connect their X account.
/// Reads connection state via CookieManager — never touches storage directly.
struct ContentView: View {

    @State private var showLogin = false
    @State private var connectionStatus: ConnectionStatus = .disconnected

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Text("Piper")
                    .font(.largeTitle.weight(.bold))

                Text("One-tap sharing from X to Instapaper.\nLog in once — Piper handles the rest.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 16) {
                if connectionStatus == .connected {
                    Label("X account connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.body.weight(.medium))
                }

                Button {
                    showLogin = true
                } label: {
                    Text(connectionStatus == .connected ? "Reconnect X Account" : "Connect X Account")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .sheet(isPresented: $showLogin, onDismiss: refreshStatus) {
            XLoginSheet(isPresented: $showLogin)
        }
        .onAppear(perform: refreshStatus)
    }

    private func refreshStatus() {
        let cookies = CookieManager.load()
        connectionStatus = cookies.isEmpty ? .disconnected : .connected
    }
}
