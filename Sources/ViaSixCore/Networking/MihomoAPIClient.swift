import Foundation

public struct MihomoAPIConfiguration: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let secret: String

    public init(host: String = "127.0.0.1", port: Int, secret: String) {
        self.host = host
        self.port = port
        self.secret = secret
    }

    public var displayAddress: String { "\(host):\(port)" }
}

public struct MihomoProxyGroup: Identifiable, Equatable, Sendable {
    public var id: String { name }
    public let name: String
    public let type: String
    public let selected: String
    public let candidates: [String]

    public init(name: String, type: String, selected: String, candidates: [String]) {
        self.name = name
        self.type = type
        self.selected = selected
        self.candidates = candidates
    }

    public var isManuallySelectable: Bool {
        type.caseInsensitiveCompare("Selector") == .orderedSame
            || type.caseInsensitiveCompare("select") == .orderedSame
    }
}

public struct MihomoProxySelectionSnapshot: Equatable, Sendable {
    public let version: String
    public let proxyGroups: [MihomoProxyGroup]
    public let fetchedAt: Date

    public init(
        version: String,
        proxyGroups: [MihomoProxyGroup],
        fetchedAt: Date = Date()
    ) {
        self.version = version
        self.proxyGroups = proxyGroups
        self.fetchedAt = fetchedAt
    }
}

public enum MihomoAPIError: LocalizedError, Equatable, Sendable {
    case invalidEndpoint
    case invalidResponse
    case rejected(status: Int, message: String)
    case responseTooLarge

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Mihomo Controller 地址无效"
        case .invalidResponse:
            "Mihomo Controller 返回了无法识别的数据"
        case .rejected(let status, let message):
            message.isEmpty ? "Mihomo Controller 请求失败（HTTP \(status)）" : message
        case .responseTooLarge:
            "Mihomo Controller 返回的数据超过安全限制"
        }
    }
}

public actor MihomoAPIClient {
    private static let maximumResponseBytes = 8 * 1_024 * 1_024

    public let configuration: MihomoAPIConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(configuration: MihomoAPIConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 4
            config.timeoutIntervalForResource = 8
            config.waitsForConnectivity = false
            config.urlCache = nil
            self.session = URLSession(configuration: config)
        }
    }

    public func proxySelectionSnapshot() async throws -> MihomoProxySelectionSnapshot {
        async let version: VersionEnvelope = get(["version"])
        async let proxies: ProxiesEnvelope = get(["proxies"])
        let (versionValue, proxiesValue) = try await (version, proxies)
        return MihomoProxySelectionSnapshot(
            version: versionValue.version,
            proxyGroups: proxiesValue.groups.filter(\.isManuallySelectable)
        )
    }

    public func selectProxy(group: String, proxy: String) async throws {
        try await send(
            method: "PUT",
            path: ["proxies", group],
            body: try encoder.encode(ProxySelection(name: proxy))
        )
    }

    private func get<Value: Decodable>(_ path: [String]) async throws -> Value {
        let data = try await data(method: "GET", path: path)
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw MihomoAPIError.invalidResponse
        }
    }

    private func send(method: String, path: [String], body: Data? = nil) async throws {
        _ = try await data(method: method, path: path, body: body)
    }

    private func data(method: String, path: [String], body: Data? = nil) async throws -> Data {
        var request = try request(path: path)
        request.httpMethod = method
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard data.count <= Self.maximumResponseBytes else {
            throw MihomoAPIError.responseTooLarge
        }
        guard let response = response as? HTTPURLResponse else {
            throw MihomoAPIError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).message) ?? ""
            throw MihomoAPIError.rejected(status: response.statusCode, message: message)
        }
        return data
    }

    private func request(path: [String]) throws -> URLRequest {
        let allowedCharacters = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        )
        let encodedPath = try path.map { segment in
            guard
                let encoded = segment.addingPercentEncoding(
                    withAllowedCharacters: allowedCharacters
                )
            else {
                throw MihomoAPIError.invalidEndpoint
            }
            return encoded
        }.joined(separator: "/")
        var components = URLComponents()
        components.scheme = "http"
        components.host = configuration.host
        components.port = configuration.port
        components.percentEncodedPath = "/" + encodedPath
        guard let url = components.url else { throw MihomoAPIError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(configuration.secret)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

private struct VersionEnvelope: Decodable {
    let version: String
}

private struct ProxySelection: Encodable {
    let name: String
}

private struct ErrorEnvelope: Decodable {
    let message: String
}

private struct ProxiesEnvelope: Decodable {
    struct ProxyValue: Decodable {
        let name: String?
        let type: String?
        let now: String?
        let all: [String]?
    }

    let proxies: [String: ProxyValue]

    var groups: [MihomoProxyGroup] {
        proxies.compactMap { key, value in
            guard let candidates = value.all, !candidates.isEmpty else { return nil }
            return MihomoProxyGroup(
                name: value.name ?? key,
                type: value.type ?? "Selector",
                selected: value.now ?? candidates[0],
                candidates: candidates
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
