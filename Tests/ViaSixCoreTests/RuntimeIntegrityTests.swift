import Foundation
import XCTest

@testable import ViaSixCore

final class RuntimeIntegrityTests: XCTestCase {
    func testInspectorRecognizesThinAndUniversalMachOArchitectures() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let thinURL = root.appendingPathComponent("thin")
        try thinMachO(for: .arm64).write(to: thinURL)
        XCTAssertEqual(
            RuntimeBinaryInspector.inspect(fileAt: thinURL),
            .machO([.arm64])
        )

        let universalURL = root.appendingPathComponent("universal")
        try universalMachO(for: [.arm64, .x8664]).write(to: universalURL)
        XCTAssertEqual(
            RuntimeBinaryInspector.inspect(fileAt: universalURL),
            .machO([.arm64, .x8664])
        )
    }

    func testInspectorRejectsTruncatedUniversalMachO() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var data = universalMachO(for: [.arm64, .x8664])
        data.removeLast()
        let url = root.appendingPathComponent("truncated-universal")
        try data.write(to: url)

        XCTAssertEqual(RuntimeBinaryInspector.inspect(fileAt: url), .invalid)
    }

    func testInstalledStatusRejectsWrongArchitectureExecutable() async throws {
        let root = makeRoot()
        let runtimeURL = root.appendingPathComponent("Runtime", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)

        let wrongArchitecture =
            RuntimeArchitecture.current == .arm64
            ? RuntimeArchitecture.x8664
            : .arm64
        let cfstURL = runtimeURL.appendingPathComponent(RuntimePayloadFile.cfst.rawValue)
        try thinMachO(for: wrongArchitecture).write(to: cfstURL)
        try makeExecutable(cfstURL)

        let status = await RuntimeComponentManager(runtimeDirectory: runtimeURL).installedStatus()

        XCTAssertEqual(status.discoveredFiles.installedFiles, [.cfst])
        XCTAssertEqual(status.invalidFiles, [.cfst])
        XCTAssertNil(status.cfstURL)
        XCTAssertFalse(status.cfstIsReady)
        XCTAssertFalse(status.isReady)
    }

    func testInstalledStatusRejectsEmptyGeoAsset() async throws {
        let root = makeRoot()
        let runtimeURL = root.appendingPathComponent("Runtime", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)

        for payload in [RuntimePayloadFile.cfst, .xray] {
            let url = runtimeURL.appendingPathComponent(payload.rawValue)
            try executableScript(marker: payload.rawValue).write(to: url)
            try makeExecutable(url)
        }
        try Data().write(to: runtimeURL.appendingPathComponent(RuntimePayloadFile.geoIP.rawValue))
        try Data("valid geosite fixture".utf8)
            .write(to: runtimeURL.appendingPathComponent(RuntimePayloadFile.geoSite.rawValue))

        let status = await RuntimeComponentManager(runtimeDirectory: runtimeURL).installedStatus()

        XCTAssertEqual(status.invalidFiles, [.geoIP])
        XCTAssertTrue(status.cfstIsReady)
        XCTAssertNil(status.geoIPURL)
        XCTAssertFalse(status.xrayIsReady)
        XCTAssertFalse(status.isReady)
    }

    func testRejectedArchitecturePreservesExistingRuntime() async throws {
        let root = makeRoot()
        let runtimeURL = root.appendingPathComponent("Runtime", isDirectory: true)
        let sourceURL = root.appendingPathComponent("Source", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)

        for payload in RuntimePayloadFile.allCases {
            let url = runtimeURL.appendingPathComponent(payload.rawValue)
            let data =
                payload.requiresExecutablePermission
                ? executableScript(marker: "existing-\(payload.rawValue)")
                : Data("existing-\(payload.rawValue)".utf8)
            try data.write(to: url)
            if payload.requiresExecutablePermission {
                try makeExecutable(url)
            }
        }
        let existingCFST = try Data(
            contentsOf: runtimeURL.appendingPathComponent(RuntimePayloadFile.cfst.rawValue)
        )

        let wrongArchitecture =
            RuntimeArchitecture.current == .arm64
            ? RuntimeArchitecture.x8664
            : .arm64
        try thinMachO(for: wrongArchitecture)
            .write(to: sourceURL.appendingPathComponent(RuntimePayloadFile.cfst.rawValue))

        let manager = RuntimeComponentManager(runtimeDirectory: runtimeURL)
        do {
            _ = try await manager.install(from: sourceURL)
            XCTFail("Expected the incompatible executable to be rejected")
        } catch let error as RuntimeComponentError {
            XCTAssertEqual(
                error,
                .incompatibleExecutableArchitecture(
                    .cfst,
                    expected: .current,
                    available: [wrongArchitecture]
                )
            )
        }

        XCTAssertEqual(
            try Data(
                contentsOf: runtimeURL.appendingPathComponent(RuntimePayloadFile.cfst.rawValue)
            ),
            existingCFST
        )
        let status = await manager.installedStatus()
        XCTAssertTrue(status.isReady)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasPrefix(".Runtime-install-") }
        XCTAssertTrue(leftovers.isEmpty, "Unexpected transaction leftovers: \(leftovers)")
    }

    func testManifestCannotMakeXrayGeoAssetsOptional() async throws {
        let root = makeRoot()
        let archiveURL = root.appendingPathComponent("archive")
        let runtimeURL = root.appendingPathComponent("Runtime", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let archiveData = Data("archive fixture".utf8)
        try archiveData.write(to: archiveURL)
        let digest = RuntimeSHA256.hexDigest(of: archiveData)
        let manifest = RuntimeManifest(assets: [
            RuntimeAsset(
                component: .cfst,
                version: "test",
                architecture: .arm64,
                archiveName: "cfst.zip",
                archiveFormat: .zip,
                downloadURL: URL(string: "https://example.invalid/cfst.zip")!,
                sha256: digest,
                payloadFiles: [.cfst]
            ),
            RuntimeAsset(
                component: .xray,
                version: "test",
                architecture: .arm64,
                archiveName: "xray.zip",
                archiveFormat: .zip,
                downloadURL: URL(string: "https://example.invalid/xray.zip")!,
                sha256: digest,
                payloadFiles: [.xray]
            ),
        ])
        let manager = RuntimeComponentManager(
            runtimeDirectory: runtimeURL,
            manifest: manifest,
            downloadHandler: { _ in
                RuntimeDownloadedFile(fileURL: archiveURL, statusCode: 200)
            },
            archiveExtractor: { _, _, destinationURL in
                let payload: RuntimePayloadFile =
                    destinationURL.lastPathComponent == RuntimeComponent.cfst.rawValue
                    ? .cfst
                    : .xray
                try Data("#!/bin/sh\nexit 0\n".utf8)
                    .write(to: destinationURL.appendingPathComponent(payload.rawValue))
            }
        )

        do {
            _ = try await manager.downloadAndInstall(architecture: .arm64)
            XCTFail("Expected missing geo assets to be rejected")
        } catch let error as RuntimeComponentError {
            XCTAssertEqual(
                error,
                .missingArchivePayload(.xray, [.geoIP, .geoSite])
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: runtimeURL.path))
    }

    func testInstallationRejectsNonCurrentArchitectureBeforeResolvingAssets() async throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let requestedArchitecture: RuntimeArchitecture =
            RuntimeArchitecture.current == .arm64 ? .x8664 : .arm64
        let manager = RuntimeComponentManager(runtimeDirectory: root)

        do {
            _ = try await manager.downloadAndInstall(architecture: requestedArchitecture)
            XCTFail("Expected a non-native installation request to be rejected")
        } catch let error as RuntimeComponentError {
            XCTAssertEqual(
                error,
                .unsupportedInstallationArchitecture(
                    requested: requestedArchitecture,
                    current: .current
                )
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    private func makeRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-RuntimeIntegrity-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeExecutable(_ url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: url.path
        )
    }

    private func executableScript(marker: String) -> Data {
        Data("#!/bin/sh\n# \(marker)\nexit 0\n".utf8)
    }

    private func thinMachO(for architecture: RuntimeArchitecture) -> Data {
        var data = Data([0xcf, 0xfa, 0xed, 0xfe])
        appendUInt32LittleEndian(cpuType(for: architecture), to: &data)
        data.append(Data(repeating: 0, count: 24))
        return data
    }

    private func universalMachO(for architectures: [RuntimeArchitecture]) -> Data {
        let slices = architectures.map { thinMachO(for: $0) }
        let entriesEnd = 8 + architectures.count * 20
        var offsets: [Int] = []
        var nextOffset = entriesEnd
        for slice in slices {
            offsets.append(nextOffset)
            nextOffset += slice.count
        }

        var data = Data([0xca, 0xfe, 0xba, 0xbe])
        appendUInt32BigEndian(UInt32(architectures.count), to: &data)
        for (index, architecture) in architectures.enumerated() {
            appendUInt32BigEndian(cpuType(for: architecture), to: &data)
            appendUInt32BigEndian(0, to: &data)
            appendUInt32BigEndian(UInt32(offsets[index]), to: &data)
            appendUInt32BigEndian(UInt32(slices[index].count), to: &data)
            appendUInt32BigEndian(0, to: &data)
        }
        for slice in slices {
            data.append(slice)
        }
        return data
    }

    private func cpuType(for architecture: RuntimeArchitecture) -> UInt32 {
        switch architecture {
        case .arm64: 0x0100_000c
        case .x8664: 0x0100_0007
        }
    }

    private func appendUInt32LittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }

    private func appendUInt32BigEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value >> 24))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }
}
