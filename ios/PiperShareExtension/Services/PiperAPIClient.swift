// PiperAPIClient.swift — Piper backend API client (Services layer)
// POSTs extracted content to the /save endpoint and returns the UUID URL.
// Never called by Views directly. Uses Config.backendBaseURL as the sole URL source.

import Foundation

// MARK: - Errors

/// Errors that can occur when communicating with the Piper backend.
public enum PiperAPIError: Error, LocalizedError {
    case httpError(statusCode: Int, message: String)
    case parseError
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case .httpError(_, let message):
            return "Failed to save: \(message)"
        case .parseError:
            return "Failed to parse server response"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Protocol (enables mocking in tests)

/// Abstracts API calls so tests can inject a mock without hitting the network.
public protocol PiperAPIClientProtocol {
    func save(title: String,
              content: String,
              completion: @escaping (Result<String, Error>) -> Void)
}

// MARK: - URLSession abstraction (enables test injection)

/// A minimal URLSession-like protocol so tests can inject a mock session.
public protocol URLSessionProtocol {
    func dataTask(with request: URLRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol
}

public protocol URLSessionDataTaskProtocol {
    func resume()
}

extension URLSession: URLSessionProtocol {
    public func dataTask(with request: URLRequest,
                         completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTaskProtocol {
        return (dataTask(with: request, completionHandler: completionHandler) as URLSessionDataTask)
    }
}

extension URLSessionDataTask: URLSessionDataTaskProtocol {}

// MARK: - PiperAPIClient

/// Sends article content to the Piper Cloudflare Worker /save endpoint.
///
/// The backend URL is taken from `Config.backendBaseURL` — never hardcoded here.
public final class PiperAPIClient: PiperAPIClientProtocol {

    // MARK: - Dependencies

    private let session: URLSessionProtocol

    /// Designated initialiser.
    /// - Parameter session: URLSession (or mock) to use for network calls.
    public init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    // MARK: - PiperAPIClientProtocol

    /// POSTs `{title, content}` to the /save endpoint and returns the UUID URL on success.
    /// The completion block is called on an arbitrary queue — callers must dispatch to main if needed.
    public func save(title: String,
                     content: String,
                     completion: @escaping (Result<String, Error>) -> Void) {
        // Build the URL from the single source of truth.
        let urlString = Config.backendBaseURL + "/save"
        guard let url = URL(string: urlString) else {
            completion(.failure(PiperAPIError.networkError(
                NSError(domain: "PiperAPIClient", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid backend URL"]))))
            return
        }

        // Encode the request body.
        let body: [String: String] = ["title": title, "content": content]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(PiperAPIError.parseError))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(PiperAPIError.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(PiperAPIError.parseError))
                return
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                // Try to surface server-provided message.
                var serverMessage = "please try again"
                if let data = data,
                   let text = String(data: data, encoding: .utf8),
                   !text.isEmpty {
                    serverMessage = text
                }
                completion(.failure(PiperAPIError.httpError(statusCode: httpResponse.statusCode,
                                                             message: serverMessage)))
                return
            }

            guard let data = data else {
                completion(.failure(PiperAPIError.parseError))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(SaveResponse.self, from: data)
                completion(.success(decoded.url))
            } catch {
                completion(.failure(PiperAPIError.parseError))
            }
        }
        task.resume()
    }
}
