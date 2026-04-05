import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import OpenAPIMock

@Suite("RecordingClientMiddleware")
struct RecordingClientMiddlewareTests {

    let baseURL = URL(string: "https://example.com")!
    let request = HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/test")
    let tempDirectory: URL

    init() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    // Returns a 200 response with the given JSON body
    func successNext(json: [String: Any] = ["id": 1, "name": "test"]) -> @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) {
        return { _, _, _ in
            let data = try JSONSerialization.data(withJSONObject: json)
            return (HTTPResponse(status: .ok), HTTPBody(data))
        }
    }

    // Returns a sentinel 418 response
    let sentinelNext: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) = { _, _, _ in
        (HTTPResponse(status: .init(code: 418)), nil)
    }

    @Test("Disabled middleware passes through to next")
    func disabledPassesThroughToNext() async throws {
        let middleware = RecordingClientMiddleware(isEnabled: false, directory: tempDirectory)
        let (response, _) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: sentinelNext
        )
        #expect(response.status.code == 418)
    }

    @Test("200 response is saved as JSON file")
    func enabled200ResponseSavesFile() async throws {
        let middleware = RecordingClientMiddleware(isEnabled: true, directory: tempDirectory)
        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: successNext()
        )
        let fileURL = tempDirectory.appending(path: "test_operation.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Saved file is pretty-printed with sorted keys")
    func enabledFileIsPrettyPrintedWithSortedKeys() async throws {
        let middleware = RecordingClientMiddleware(isEnabled: true, directory: tempDirectory)
        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation",
            next: successNext(json: ["z_key": "last", "a_key": "first"])
        )
        let fileURL = tempDirectory.appending(path: "test_operation.json")
        let content = try String(contentsOf: fileURL)
        #expect(content.contains("\n"))
        let aKeyRange = try #require(content.range(of: "a_key"))
        let zKeyRange = try #require(content.range(of: "z_key"))
        #expect(aKeyRange.lowerBound < zKeyRange.lowerBound)
    }

    @Test("Non-200 response is not saved")
    func enabledNon200ResponseDoesNotSaveFile() async throws {
        let middleware = RecordingClientMiddleware(isEnabled: true, directory: tempDirectory)
        let errorNext: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) = { _, _, _ in
            (HTTPResponse(status: .notFound), nil)
        }
        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: errorNext
        )
        let fileURL = tempDirectory.appending(path: "test_operation.json")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Response body is preserved after recording")
    func enabledResponseBodyPreserved() async throws {
        let middleware = RecordingClientMiddleware(isEnabled: true, directory: tempDirectory)
        let (_, body) = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: successNext(json: ["id": 1, "name": "test"])
        )
        let data = try await Data(collecting: body!, upTo: Int.max)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["name"] as? String == "test")
    }

    @Test("Custom directory is used for saving")
    func enabledCustomDirectoryUsedForSaving() async throws {
        let customDir = tempDirectory.appending(path: "custom")
        try FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        let middleware = RecordingClientMiddleware(isEnabled: true, directory: customDir)
        _ = try await middleware.intercept(
            request, body: nil, baseURL: baseURL,
            operationID: "test_operation", next: successNext()
        )
        let fileURL = customDir.appending(path: "test_operation.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
