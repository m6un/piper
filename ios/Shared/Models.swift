// Models.swift — Shared data types (Models layer)
// Used by both the main Piper app and the PiperShareExtension.

import Foundation

/// Represents the connection state for an X account.
enum ConnectionState: Equatable {
    case disconnected
    case connected
}

/// Content extracted from a web page by readability.js.
public struct ExtractedContent {
    public let title: String
    public let content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}

/// The response returned by the backend /save endpoint.
public struct SaveResponse: Decodable {
    /// The ephemeral UUID URL under which the content is stored (TTL 3600s).
    public let url: String
}
