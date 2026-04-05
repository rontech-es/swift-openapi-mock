import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import OpenAPIMock

@Suite("MockClientMiddleware")
struct MockClientMiddlewareTests {

    let baseURL = URL(string: "https://example.com")!
    let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/test")

    // Returns a sentinel 418 response to detect if next was called
    let sentinelNext: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) = { _, _, _ in
        (HTTPResponse(status: .init(code: 418)), nil)
    }

    @Test("Disabled middleware passes through to next")
    func disabledPassesThroughToNext() async throws {
        let middleware = MockClientMiddleware(isEnabled: false)
        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: sentinelNext
        )
        #expect(response.status.code == 418)
    }

    @Test("Enabled middleware returns 200 when file is found")
    func enabledFileFoundReturns200() async throws {
        let middleware = MockClientMiddleware(
            isEnabled: true,
            simulatedLatency: .zero,
            bundle: .module,
            subdirectory: "MockResponses"
        )
        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: sentinelNext
        )
        #expect(response.status == .ok)
        #expect(response.headerFields[.contentType] == "application/json")
    }

    @Test("Enabled middleware returns correct body when file is found")
    func enabledFileFoundReturnsCorrectBody() async throws {
        let middleware = MockClientMiddleware(
            isEnabled: true,
            simulatedLatency: .zero,
            bundle: .module,
            subdirectory: "MockResponses"
        )
        let (_, body) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: sentinelNext
        )
        let data = try await Data(collecting: body!, upTo: Int.max)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["message"] as? String == "hello")
    }

    @Test("Enabled middleware falls through to next when file is not found")
    func enabledFileNotFoundPassesThroughToNext() async throws {
        let middleware = MockClientMiddleware(
            isEnabled: true,
            simulatedLatency: .zero,
            bundle: .module,
            subdirectory: "MockResponses"
        )
        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "unknown_operation", next: sentinelNext
        )
        #expect(response.status.code == 418)
    }

    @Test("Custom subdirectory is used for file lookup")
    func customSubdirectoryUsedForLookup() async throws {
        let middleware = MockClientMiddleware(
            isEnabled: true,
            simulatedLatency: .zero,
            bundle: .module,
            subdirectory: "WrongFolder"
        )
        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: sentinelNext
        )
        // File won't be found in wrong folder, so next is called
        #expect(response.status.code == 418)
    }
}
