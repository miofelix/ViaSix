import Foundation
import XCTest

@testable import ViaSixCore

final class MihomoAPIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MihomoAPIURLProtocol.fixture.reset()
    }

    func testProxySelectionSnapshotDecodesOnlyManualGroups() async throws {
        MihomoAPIURLProtocol.fixture.responses = [
            "/version": Data(#"{"meta":true,"version":"v1.19.29"}"#.utf8),
            "/proxies": Data(
                #"{"proxies":{"Auto":{"name":"Auto","type":"URLTest","now":"edge","all":["edge","DIRECT"]},"GLOBAL":{"name":"GLOBAL","type":"Selector","now":"edge","all":["edge","DIRECT"]},"Fallback":{"name":"Fallback","type":"select","now":"DIRECT","all":["DIRECT","edge"]},"edge":{"name":"edge","type":"VLESS"}}}"#
                    .utf8
            ),
        ]
        let client = makeClient()

        let snapshot = try await client.proxySelectionSnapshot()

        XCTAssertEqual(snapshot.version, "v1.19.29")
        XCTAssertEqual(snapshot.proxyGroups.map(\.name), ["Fallback", "GLOBAL"])
        XCTAssertEqual(snapshot.proxyGroups.first?.selected, "DIRECT")
        XCTAssertEqual(snapshot.proxyGroups.last?.candidates, ["edge", "DIRECT"])
        XCTAssertEqual(
            Set(MihomoAPIURLProtocol.fixture.requests.map(\.path)),
            Set(["/version", "/proxies"])
        )
        XCTAssertTrue(
            MihomoAPIURLProtocol.fixture.authorizationHeaders.allSatisfy {
                $0 == "Bearer test-secret"
            }
        )
    }

    func testSelectProxyEncodesGroupAsSinglePathSegmentAndBody() async throws {
        MihomoAPIURLProtocol.fixture.responses = [
            "/proxies/Group%2F%E4%B8%BB": Data()
        ]
        let client = makeClient()

        try await client.selectProxy(group: "Group/主", proxy: "edge")

        let request = try XCTUnwrap(MihomoAPIURLProtocol.fixture.requests.first)
        XCTAssertEqual(request.method, "PUT")
        XCTAssertEqual(request.path, "/proxies/Group%2F%E4%B8%BB")
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: try XCTUnwrap(request.body)) as? [String: String],
            ["name": "edge"]
        )
    }

    private func makeClient() -> MihomoAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MihomoAPIURLProtocol.self]
        return MihomoAPIClient(
            configuration: MihomoAPIConfiguration(port: 9_090, secret: "test-secret"),
            session: URLSession(configuration: configuration)
        )
    }
}

private final class MihomoAPIURLProtocol: URLProtocol {
    static let fixture = MihomoAPIProtocolFixture()

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let responseData = Self.fixture.response(for: request)
        guard let url = request.url,
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class MihomoAPIProtocolFixture: @unchecked Sendable {
    struct RecordedRequest: Sendable {
        let method: String
        let path: String
        let body: Data?
    }

    private let lock = NSLock()
    private var storedResponses: [String: Data] = [:]
    private var storedRequests: [RecordedRequest] = []
    private var storedAuthorizationHeaders: [String] = []

    var responses: [String: Data] {
        get { withLock { storedResponses } }
        set { withLock { storedResponses = newValue } }
    }

    var requests: [RecordedRequest] { withLock { storedRequests } }
    var authorizationHeaders: [String] { withLock { storedAuthorizationHeaders } }

    func response(for request: URLRequest) -> Data {
        withLock {
            let path =
                request.url.flatMap {
                    URLComponents(url: $0, resolvingAgainstBaseURL: false)?.percentEncodedPath
                } ?? ""
            storedRequests.append(
                RecordedRequest(
                    method: request.httpMethod ?? "GET",
                    path: path,
                    body: requestBody(request)
                )
            )
            storedAuthorizationHeaders.append(
                request.value(forHTTPHeaderField: "Authorization") ?? ""
            )
            return storedResponses[path] ?? Data("{}".utf8)
        }
    }

    private func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }

    func reset() {
        withLock {
            storedResponses = [:]
            storedRequests = []
            storedAuthorizationHeaders = []
        }
    }

    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
