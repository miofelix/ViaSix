import Foundation

public struct RuntimeReleaseResponse: Equatable, Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public typealias RuntimeReleaseLoader = @Sendable (URL) async throws -> RuntimeReleaseResponse

public struct RuntimeReleaseResolver: Sendable {
    private static let networkSession = RuntimeNetworkPolicy.makeSession(
        requestTimeout: RuntimeNetworkPolicy.releaseRequestTimeout,
        resourceTimeout: RuntimeNetworkPolicy.releaseResourceTimeout
    )

    private let loader: RuntimeReleaseLoader

    public init() {
        self.loader = Self.loadUsingURLSession
    }

    public init(loader: @escaping RuntimeReleaseLoader) {
        self.loader = loader
    }

    public func latestAssets(for architecture: RuntimeArchitecture) async throws -> [RuntimeAsset] {
        try await withThrowingTaskGroup(of: RuntimeAsset.self) { group in
            for component in RuntimeComponent.allCases {
                group.addTask {
                    try await resolve(component: component, architecture: architecture)
                }
            }

            var resolved: [RuntimeComponent: RuntimeAsset] = [:]
            for try await asset in group {
                resolved[asset.component] = asset
            }
            return try RuntimeComponent.allCases.map { component in
                guard let asset = resolved[component] else {
                    throw RuntimeComponentError.missingLatestRelease(component)
                }
                return asset
            }
        }
    }

    private func resolve(
        component: RuntimeComponent,
        architecture: RuntimeArchitecture
    ) async throws -> RuntimeAsset {
        let apiURL = component.latestReleaseAPIURL
        let response = try await loader(apiURL)
        guard (200...299).contains(response.statusCode) else {
            throw RuntimeComponentError.httpStatus(response.statusCode, apiURL)
        }

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: response.data)
        } catch {
            throw RuntimeComponentError.invalidLatestRelease(component)
        }

        let archiveName = component.archiveName(for: architecture)
        guard let releaseAsset = release.assets.first(where: { $0.name == archiveName }) else {
            throw RuntimeComponentError.missingLatestReleaseAsset(component, archiveName)
        }
        guard releaseAsset.downloadURL.host?.lowercased() == "github.com" else {
            throw RuntimeComponentError.invalidLatestRelease(component)
        }
        guard let digest = releaseAsset.digest,
            digest.lowercased().hasPrefix("sha256:")
        else {
            throw RuntimeComponentError.missingLatestReleaseDigest(component, archiveName)
        }
        let sha256 = String(digest.dropFirst("sha256:".count)).lowercased()
        guard sha256.count == 64, sha256.allSatisfy(\.isHexDigit) else {
            throw RuntimeComponentError.missingLatestReleaseDigest(component, archiveName)
        }

        let version =
            release.tagName.hasPrefix("v")
            ? String(release.tagName.dropFirst())
            : release.tagName
        guard !version.isEmpty else {
            throw RuntimeComponentError.invalidLatestRelease(component)
        }

        return RuntimeAsset(
            component: component,
            version: version,
            architecture: architecture,
            archiveName: archiveName,
            archiveFormat: .zip,
            downloadURL: releaseAsset.downloadURL,
            sha256: sha256,
            payloadFiles: component.payloadFiles
        )
    }

    private static func loadUsingURLSession(_ url: URL) async throws -> RuntimeReleaseResponse {
        try await loadUsingURLSession(url, using: networkSession)
    }

    static func loadUsingURLSession(
        _ url: URL,
        using session: URLSession
    ) async throws -> RuntimeReleaseResponse {
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ViaSix", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw RuntimeComponentError.invalidDownloadResponse(url)
        }
        return RuntimeReleaseResponse(data: data, statusCode: response.statusCode)
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let assets: [GitHubAsset]

        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let downloadURL: URL
        let digest: String?

        private enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
            case digest
        }
    }
}

enum RuntimeNetworkPolicy {
    static let releaseRequestTimeout: TimeInterval = 20
    static let releaseResourceTimeout: TimeInterval = 45
    static let downloadRequestTimeout: TimeInterval = 30
    static let downloadResourceTimeout: TimeInterval = 10 * 60

    static func makeSession(
        requestTimeout: TimeInterval,
        resourceTimeout: TimeInterval,
        protocolClasses: [AnyClass]? = nil
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.waitsForConnectivity = false
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(configuration: configuration)
    }
}
