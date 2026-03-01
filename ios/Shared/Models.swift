import Foundation

/// Shared data types used across the main app and Share Extension targets.

/// Represents the X account connection state shown in the main app UI.
public enum ConnectionStatus: Equatable {
    /// No cookies are stored; the user has not logged in.
    case disconnected
    /// Cookies are present in the App Group; the session should be active.
    case connected
}
