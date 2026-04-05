import Foundation
import OpenAPIRuntime
import HTTPTypes

/// A ``ClientMiddleware`` that serves bundled JSON files by operationID.
///
/// Place JSON files named `<operationID>.json` inside your app bundle under a
/// folder of your choice (default: `MockResponses`).
///
/// - If a file is found, it is returned with a `200 application/json` response
///   after an optional simulated latency.
/// - If no file is found, the request falls through to the real network and a
///   console warning is printed.
///
/// ```swift
/// let mock = MockClientMiddleware(isEnabled: true)
/// let client = Client(serverURL: baseURL, transport: transport, middlewares: [mock])
/// ```
public struct MockClientMiddleware: ClientMiddleware {

    private let isEnabled: Bool
    private let simulatedLatency: Duration
    private let bundle: Bundle
    private let subdirectory: String?
    private let verbose: Bool

    /// Creates a new ``MockClientMiddleware``.
    ///
    /// - Parameters:
    ///   - isEnabled: When `false`, the middleware is a pure pass-through with zero overhead.
    ///   - simulatedLatency: Artificial delay before returning the mock response. Pass `.zero` in tests.
    ///   - bundle: The bundle to search for mock JSON files. Defaults to `Bundle.main`.
    ///   - subdirectory: The folder inside the bundle where mock files are located. Defaults to `MockResponses`.
    ///   - verbose: When `false`, suppresses all console output. Defaults to `true`.
    public init(
        isEnabled: Bool,
        simulatedLatency: Duration = .milliseconds(800),
        bundle: Bundle = .main,
        subdirectory: String? = "MockResponses",
        verbose: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.simulatedLatency = simulatedLatency
        self.bundle = bundle
        self.subdirectory = subdirectory
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

        guard
            let fileURL = bundle.url(forResource: operationID, withExtension: "json", subdirectory: subdirectory),
            let data = try? Data(contentsOf: fileURL)
        else {
            if verbose {
                let location = subdirectory.map { "'\($0)/'" } ?? "bundle root"
                print("""
                    ⚠️ [OpenAPIMock] No mock found for '\(operationID)' in \(location) — falling through to network.
                       To capture this response, enable RecordingClientMiddleware and run the app once.
                    """)
            }
            return try await next(request, body, baseURL)
        }

        if simulatedLatency > .zero {
            try await Task.sleep(for: simulatedLatency)
        }

        if verbose {
            print("✅ [OpenAPIMock] Serving '\(operationID).json' from bundle")
        }
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(data))
    }
}
