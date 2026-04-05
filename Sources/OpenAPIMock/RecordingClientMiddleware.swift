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
    private let verbose: Bool

    /// Creates a new ``RecordingClientMiddleware``.
    ///
    /// - Parameters:
    ///   - isEnabled: When `false`, the middleware is a pure pass-through with zero overhead.
    ///   - directory: Directory where recorded JSON files are saved.
    ///     Defaults to `MockResponses/` inside the app's Documents directory.
    ///   - verbose: When `false`, suppresses all console output. Defaults to `true`.
    public init(
        isEnabled: Bool,
        directory: URL = .documentsDirectory.appending(path: "MockResponses"),
        verbose: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.directory = directory
        self.verbose = verbose
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
            let fileURL = directory.appending(path: "\(operationID).json")
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try prettyData.write(to: fileURL)
                if verbose {
                    print("✅ [OpenAPIMock] Recorded '\(operationID)' → \(fileURL.path)")
                }
            } catch {
                if verbose {
                    print("⚠️ [OpenAPIMock] Failed to write '\(operationID).json' — \(error.localizedDescription)")
                }
            }
        } else if verbose {
            print("⚠️ [OpenAPIMock] Failed to record '\(operationID)' — response body could not be serialized.")
        }

        return (response, HTTPBody(data))
    }
}
