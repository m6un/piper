// Models.swift — Shared data types (Models layer)
// Used by both the main Piper app and the PiperShareExtension.

import Foundation

/// Represents the connection state for an X account.
enum ConnectionState: Equatable {
    case disconnected
    case connected
}
