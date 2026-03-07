// Config.swift — App-wide constants (Models layer)
// Single source of truth for configuration values shared across targets.
// Never hardcode the backend URL elsewhere — always reference Config.backendBaseURL.

import Foundation

/// App-wide configuration constants.
public enum Config {
    /// The base URL of the Piper Cloudflare Worker backend.
    /// No trailing slash.
    public static let backendBaseURL = "https://piper.workers.dev"
}
