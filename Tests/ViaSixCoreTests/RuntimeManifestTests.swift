import Foundation
import XCTest

@testable import ViaSixCore

final class RuntimeManifestTests: XCTestCase {
    func testPinnedVersionsAndAssetsForEveryArchitecture() throws {
        XCTAssertEqual(RuntimeManifest.cfstVersion, "2.3.5")
        XCTAssertEqual(RuntimeManifest.xrayVersion, "26.3.27")
        XCTAssertEqual(RuntimeManifest.current.assets.count, 4)
        XCTAssertEqual(Set(RuntimeArchitecture.allCases), [.arm64, .x8664])

        let cases:
            [(
                component: RuntimeComponent,
                architecture: RuntimeArchitecture,
                archiveName: String,
                url: String,
                sha256: String,
                payloadFiles: [RuntimePayloadFile]
            )] = [
                (
                    .cfst,
                    .arm64,
                    "cfst_darwin_arm64.zip",
                    "https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.5/cfst_darwin_arm64.zip",
                    "0623f6d24c939e3d3716f556f4d39c7b8781cf6600ee838a1b64e6b2fe4609dc",
                    [.cfst]
                ),
                (
                    .cfst,
                    .x8664,
                    "cfst_darwin_amd64.zip",
                    "https://github.com/XIU2/CloudflareSpeedTest/releases/download/v2.3.5/cfst_darwin_amd64.zip",
                    "66ce3ae89430e851cab9710d54b6d91324e0aae255f0c92a91072d57724561d5",
                    [.cfst]
                ),
                (
                    .xray,
                    .arm64,
                    "Xray-macos-arm64-v8a.zip",
                    "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-macos-arm64-v8a.zip",
                    "2e93a67e8aa1936ecefb307e120830fcbd4c643ab9b1c46a2d0838d5f8409eaf",
                    [.xray, .geoIP, .geoSite]
                ),
                (
                    .xray,
                    .x8664,
                    "Xray-macos-64.zip",
                    "https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-macos-64.zip",
                    "f5b0471d3459eff1b82e48af0aeac186abcc3298210070afbbbd8437a4e8b203",
                    [.xray, .geoIP, .geoSite]
                ),
            ]

        for expected in cases {
            let asset = try XCTUnwrap(
                RuntimeManifest.current.asset(
                    for: expected.component,
                    architecture: expected.architecture
                )
            )
            XCTAssertEqual(asset.archiveName, expected.archiveName)
            XCTAssertEqual(asset.downloadURL.absoluteString, expected.url)
            XCTAssertEqual(asset.sha256, expected.sha256)
            XCTAssertEqual(asset.payloadFiles, expected.payloadFiles)
            XCTAssertEqual(asset.sha256.count, 64)
            XCTAssertTrue(asset.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        }
    }

    func testAssetsForArchitectureAreCompleteAndOrdered() {
        for architecture in RuntimeArchitecture.allCases {
            let assets = RuntimeManifest.current.assets(for: architecture)
            XCTAssertEqual(assets.map(\.component), [.cfst, .xray])
            XCTAssertTrue(assets.allSatisfy { $0.architecture == architecture })
        }
    }

    func testLatestReleaseResolverBuildsAssetsFromGitHubMetadata() async throws {
        let resolver = RuntimeReleaseResolver { url in
            if url == RuntimeComponent.cfst.latestReleaseAPIURL {
                return RuntimeReleaseResponse(
                    data: Data(
                        #"{"tag_name":"v9.1.0","assets":[{"name":"cfst_darwin_arm64.zip","browser_download_url":"https://github.com/XIU2/CloudflareSpeedTest/releases/download/v9.1.0/cfst_darwin_arm64.zip","digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}"#
                            .utf8
                    ),
                    statusCode: 200
                )
            }
            return RuntimeReleaseResponse(
                data: Data(
                    #"{"tag_name":"v10.2.0","assets":[{"name":"Xray-macos-arm64-v8a.zip","browser_download_url":"https://github.com/XTLS/Xray-core/releases/download/v10.2.0/Xray-macos-arm64-v8a.zip","digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}]}"#
                        .utf8
                ),
                statusCode: 200
            )
        }

        let assets = try await resolver.latestAssets(for: .arm64)
        XCTAssertEqual(assets.map(\.component), [.cfst, .xray])
        XCTAssertEqual(assets.map(\.version), ["9.1.0", "10.2.0"])
        XCTAssertEqual(assets[0].sha256, String(repeating: "a", count: 64))
        XCTAssertEqual(assets[1].payloadFiles, [.xray, .geoIP, .geoSite])
    }

    func testLatestReleaseResolverRequiresSHA256Digest() async {
        let resolver = RuntimeReleaseResolver { url in
            let component = url == RuntimeComponent.cfst.latestReleaseAPIURL ? "cfst" : "xray"
            let name = component == "cfst" ? "cfst_darwin_arm64.zip" : "Xray-macos-arm64-v8a.zip"
            let repository = component == "cfst" ? "XIU2/CloudflareSpeedTest" : "XTLS/Xray-core"
            var asset: [String: Any] = [
                "name": name,
                "browser_download_url":
                    "https://github.com/\(repository)/releases/download/v1.0.0/\(name)",
            ]
            if component == "xray" {
                asset["digest"] = "sha256:\(String(repeating: "b", count: 64))"
            }
            let data = try JSONSerialization.data(withJSONObject: [
                "tag_name": "v1.0.0",
                "assets": [asset],
            ])
            return RuntimeReleaseResponse(data: data, statusCode: 200)
        }

        do {
            _ = try await resolver.latestAssets(for: .arm64)
            XCTFail("Expected missing digest to fail")
        } catch let error as RuntimeComponentError {
            XCTAssertEqual(
                error,
                .missingLatestReleaseDigest(.cfst, "cfst_darwin_arm64.zip")
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSHA256ForDataAndFile() throws {
        let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        let data = Data("abc".utf8)
        XCTAssertEqual(RuntimeSHA256.hexDigest(of: data), expected)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-SHA256-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try data.write(to: fileURL)
        XCTAssertEqual(try RuntimeSHA256.hexDigest(ofFileAt: fileURL), expected)
    }

    func testRuntimeModelsAreSendable() {
        assertSendable(RuntimeArchitecture.arm64)
        assertSendable(RuntimeComponent.cfst)
        assertSendable(RuntimePayloadFile.xray)
        assertSendable(RuntimeManifest.current)
        assertSendable(RuntimeManifest.current.assets[0])
        assertSendable(RuntimeDiscoveredFiles())
        assertSendable(
            RuntimeInstallationStatus(
                runtimeDirectory: URL(fileURLWithPath: "/tmp/Runtime"),
                discoveredFiles: RuntimeDiscoveredFiles(),
                executableFiles: []
            )
        )
        assertSendable(RuntimeComponentError.sourceNotFound(URL(fileURLWithPath: "/tmp/missing")))
    }

    func testManagedXrayRequiresBothGeoAssetsBeforeItIsReady() {
        let runtimeDirectory = URL(fileURLWithPath: "/tmp/runtime")
        let xrayURL = runtimeDirectory.appendingPathComponent("xray")
        let geoIPURL = runtimeDirectory.appendingPathComponent("geoip.dat")
        let incomplete = RuntimeInstallationStatus(
            runtimeDirectory: runtimeDirectory,
            discoveredFiles: RuntimeDiscoveredFiles(files: [
                .xray: xrayURL,
                .geoIP: geoIPURL,
            ]),
            executableFiles: [.xray]
        )

        XCTAssertFalse(incomplete.xrayIsReady)
        XCTAssertFalse(incomplete.isReady)

        let complete = RuntimeInstallationStatus(
            runtimeDirectory: runtimeDirectory,
            discoveredFiles: RuntimeDiscoveredFiles(files: [
                .cfst: runtimeDirectory.appendingPathComponent("cfst"),
                .xray: xrayURL,
                .geoIP: geoIPURL,
                .geoSite: runtimeDirectory.appendingPathComponent("geosite.dat"),
            ]),
            executableFiles: [.cfst, .xray]
        )
        XCTAssertTrue(complete.cfstIsReady)
        XCTAssertTrue(complete.xrayIsReady)
        XCTAssertTrue(complete.isReady)
    }

    func testDiscoversAndAtomicallyInstallsLocalPayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-Runtime-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("Source/Nested", isDirectory: true)
        let runtime = root.appendingPathComponent("Application Support/Runtime", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

        for payload in RuntimePayloadFile.allCases {
            try runtimeFixtureData(for: payload, marker: "first")
                .write(to: source.appendingPathComponent(payload.rawValue))
        }

        let manager = RuntimeComponentManager(runtimeDirectory: runtime)
        let initialStatus = await manager.installedStatus()
        XCTAssertFalse(initialStatus.isInstalled)

        let discovered = try await manager.discover(in: root.appendingPathComponent("Source"))
        XCTAssertEqual(discovered.installedFiles, Set(RuntimePayloadFile.allCases))

        let installedStatus = try await manager.install(from: root.appendingPathComponent("Source"))
        XCTAssertTrue(installedStatus.isReady)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: try XCTUnwrap(installedStatus.cfstURL).path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: try XCTUnwrap(installedStatus.xrayURL).path))

        let replacementSource = root.appendingPathComponent("Replacement", isDirectory: true)
        try FileManager.default.createDirectory(at: replacementSource, withIntermediateDirectories: true)
        try runtimeFixtureData(for: .cfst, marker: "replacement")
            .write(to: replacementSource.appendingPathComponent(RuntimePayloadFile.cfst.rawValue))

        let updatedStatus = try await manager.install(from: replacementSource)
        XCTAssertTrue(updatedStatus.isReady)
        XCTAssertEqual(
            try Data(contentsOf: try XCTUnwrap(updatedStatus.cfstURL)),
            runtimeFixtureData(for: .cfst, marker: "replacement")
        )
        XCTAssertEqual(
            try Data(contentsOf: try XCTUnwrap(updatedStatus.xrayURL)),
            runtimeFixtureData(for: .xray, marker: "first")
        )
    }

    func testDownloadedArchiveIsVerifiedBeforeUse() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-Download-\(UUID().uuidString)", isDirectory: true)
        let fixture = root.appendingPathComponent("fixture.zip")
        let destination = root.appendingPathComponent("Downloads", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let archiveData = Data("deterministic archive fixture".utf8)
        try archiveData.write(to: fixture)

        let asset = RuntimeAsset(
            component: .cfst,
            version: "test",
            architecture: .arm64,
            archiveName: "verified.zip",
            downloadURL: URL(string: "https://example.invalid/verified.zip")!,
            sha256: RuntimeSHA256.hexDigest(of: archiveData),
            payloadFiles: [.cfst]
        )
        let manager = RuntimeComponentManager(
            runtimeDirectory: root.appendingPathComponent("Runtime"),
            manifest: RuntimeManifest(assets: [asset]),
            downloadHandler: { _ in RuntimeDownloadedFile(fileURL: fixture, statusCode: 200) },
            archiveExtractor: { _, _ in }
        )

        let downloadedURL = try await manager.download(asset, to: destination)
        XCTAssertEqual(try Data(contentsOf: downloadedURL), archiveData)
    }

    func testChecksumMismatchRejectsAndRemovesArchive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-Bad-Download-\(UUID().uuidString)", isDirectory: true)
        let fixture = root.appendingPathComponent("fixture.zip")
        let destination = root.appendingPathComponent("Downloads", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let archiveData = Data("tampered archive".utf8)
        try archiveData.write(to: fixture)

        let badHash = String(repeating: "0", count: 64)
        let asset = RuntimeAsset(
            component: .cfst,
            version: "test",
            architecture: .arm64,
            archiveName: "rejected.zip",
            downloadURL: URL(string: "https://example.invalid/rejected.zip")!,
            sha256: badHash,
            payloadFiles: [.cfst]
        )
        let manager = RuntimeComponentManager(
            runtimeDirectory: root.appendingPathComponent("Runtime"),
            manifest: RuntimeManifest(assets: [asset]),
            downloadHandler: { _ in RuntimeDownloadedFile(fileURL: fixture, statusCode: 200) },
            archiveExtractor: { _, _ in }
        )

        do {
            _ = try await manager.download(asset, to: destination)
            XCTFail("Expected checksum mismatch")
        } catch let error as RuntimeComponentError {
            XCTAssertEqual(
                error,
                .checksumMismatch(
                    archiveName: asset.archiveName,
                    expected: badHash,
                    actual: RuntimeSHA256.hexDigest(of: archiveData)
                )
            )
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.appendingPathComponent(asset.archiveName).path
            )
        )
    }

    private func assertSendable<Value: Sendable>(_ value: Value) {
        _ = value
    }

    private func runtimeFixtureData(
        for payload: RuntimePayloadFile,
        marker: String
    ) -> Data {
        if payload.requiresExecutablePermission {
            return Data("#!/bin/sh\n# \(marker)-\(payload.rawValue)\nexit 0\n".utf8)
        }
        return Data("\(marker)-\(payload.rawValue)".utf8)
    }
}
