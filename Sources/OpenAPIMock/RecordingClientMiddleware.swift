import Foundation
import OpenAPIRuntime
import HTTPTypes

/// A ``ClientMiddleware`` that records real API responses as JSON files.
///
/// Responses are saved as `<operationID>.json` to the app's Documents directory.
/// Use the provided `export-mock-responses.sh` script to pull them into your
/// project's mock folder after recording.
///
/// Only `200` responses are recorded — error states are never persisted as mock files.
/// Saved files are pretty-printed with sorted keys for clean diffs in version control.
///
/// ```swift
/// let recorder = RecordingClientMiddleware(isEnabled: true)
/// let client = Client(serverURL: baseURL, transport: transport, middlewares: [recorder])
/// ```
public struct RecordingClientMiddleware: ClientMiddleware {

    private let isEnabled: Bool
    private let directory: URL

    /// Creates a new ``RecordingClientMiddleware``.
    ///
    /// - Parameters:
    ///   - isEnabled: When `false`, the middleware is a pure pass-through with zero overhead.
    ///   - directory: Directory where recorded JSON files are saved.
    ///     Defaults to the app's Documents directory.
    public init(
        isEnabled: Bool,
        directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    ) {
        self.isEnabled = isEnabled
        self.directory = directory
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard isEnabled else {
            return try await next(request, body, baseURL)
        }

        let (response, responseBody) = try await next(request, body, baseURL)

        guard response.status == .ok, let responseBody else {
            return (response, responseBody)
        }

        let data = try await Data(collecting: responseBody, upTo: Int.max)

        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(
               withJSONObject: json,
               options: [.prettyPrinted, .sortedKeys]
           ) {
            let fileURL = directory.appendingPathComponent("\(operationID).json")
            try? prettyData.write(to: fileURL)
            print("[OpenAPIMock] Recorded '\(operationID)' → \(fileURL.path)")
        }

        return (response, HTTPBody(data))
    }
}
