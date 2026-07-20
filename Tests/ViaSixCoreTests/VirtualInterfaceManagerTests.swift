import XCTest

@testable import ViaSixCore

final class VirtualInterfaceManagerTests: XCTestCase {
    func testNetworkAccessModeIsSingleAndDecodesCommonAliases() throws {
        XCTAssertEqual(NetworkAccessMode.localProxy.displayName, "本地代理")
        XCTAssertTrue(NetworkAccessMode.systemProxy.usesSystemProxy)
        XCTAssertTrue(NetworkAccessMode.virtualInterface.usesVirtualInterface)

        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(NetworkAccessMode.self, from: Data(#""tun""#.utf8)), .virtualInterface)
        XCTAssertEqual(try decoder.decode(NetworkAccessMode.self, from: Data(#""system-proxy""#.utf8)), .systemProxy)
        XCTAssertThrowsError(try decoder.decode(NetworkAccessMode.self, from: Data(#""both""#.utf8)))
    }

    func testParsesXrayVersionOutputAndIgnoresGoVersion() throws {
        let output = "Xray 26.7.11 (Xray, Penetrates Everything.) d2758a0 (go1.26.1 darwin/arm64)"
        let version = try XCTUnwrap(XrayRuntimeVersion.parse(output))
        XCTAssertEqual(version, XrayRuntimeVersion(26, 7, 11))
        XCTAssertEqual(version.description, "26.7.11")
        XCTAssertEqual(XrayRuntimeVersion.minimumSafe, XrayRuntimeVersion(26, 7, 11))
        XCTAssertNil(XrayRuntimeVersion.parse("xray development build without a version"))
    }

    func testVersionComparisonTreatsReleaseAsNewerThanPrerelease() {
        XCTAssertLessThan(XrayRuntimeVersion(26, 7, 11), XrayRuntimeVersion(27, 0, 0))
        XCTAssertLessThan(
            XrayRuntimeVersion(major: 26, minor: 7, patch: 11, prerelease: "rc1"),
            XrayRuntimeVersion(26, 7, 11)
        )
        XCTAssertGreaterThanOrEqual(XrayRuntimeVersion(26, 7, 11), .minimumSafe)
        XCTAssertLessThan(XrayRuntimeVersion(26, 7, 10), .minimumSafe)
    }

    func testFeatureSetRequiresExplicitDNSManagement() {
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.ipv4))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.ipv6))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.systemRouting))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.loopbackPrevention))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.crashRecovery))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.networkChangeRecovery))
        XCTAssertTrue(VirtualInterfaceFeature.minimumSafe.contains(.dnsManagement))
        XCTAssertEqual(VirtualInterfaceFeature.systemRoutes, .systemRouting)
    }

    func testCapabilityEvaluationFailsClosedInDeterministicOrder() {
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(.unsupportedBuild),
            .unavailable(.unsupportedBuild)
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(VirtualInterfaceProbe()),
            .unavailable(.runtimeMissing)
        )

        let oldRuntime = VirtualInterfaceProbe(
            runtimeVersion: XrayRuntimeVersion(26, 3, 27),
            helperAvailable: true,
            permissionAvailable: true
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(oldRuntime),
            .unavailable(
                .runtimeTooOld(installed: XrayRuntimeVersion(26, 3, 27), minimum: .minimumSafe)
            )
        )

        let currentRuntime = XrayRuntimeVersion.minimumSafe
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(
                VirtualInterfaceProbe(
                    runtimeVersion: currentRuntime,
                    supportedFeatures: .minimumSafe
                )
            ),
            .unavailable(.helperUnavailable)
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(
                VirtualInterfaceProbe(
                    runtimeVersion: currentRuntime,
                    helperAvailable: true,
                    supportedFeatures: .minimumSafe
                )
            ),
            .unavailable(.permissionUnavailable)
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(
                VirtualInterfaceProbe(
                    runtimeVersion: currentRuntime,
                    helperAvailable: true,
                    permissionAvailable: true
                )
            ),
            .unavailable(.unsupportedBuild)
        )

        let available = VirtualInterfaceCapability.evaluate(
            VirtualInterfaceProbe(
                runtimeVersion: currentRuntime,
                helperAvailable: true,
                permissionAvailable: true,
                supportedFeatures: .minimumSafe
            )
        )
        XCTAssertTrue(available.isAvailable)
        XCTAssertTrue(available.isAvailableForUI)
        XCTAssertTrue(available.features.contains(.loopbackPrevention))
    }

    func testMissingRequiredFeatureFailsAsUnsupportedBuild() {
        let probe = VirtualInterfaceProbe(
            runtimeVersion: .minimumSafe,
            helperAvailable: true,
            permissionAvailable: true,
            supportedFeatures: [.ipv4, .ipv6, .systemRouting],
            requiredFeatures: .minimumSafe
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(probe),
            .unavailable(.unsupportedBuild)
        )

        let cannotWeakenBaseline = VirtualInterfaceProbe(
            runtimeVersion: .minimumSafe,
            helperAvailable: true,
            permissionAvailable: true,
            supportedFeatures: [],
            requiredFeatures: []
        )
        XCTAssertEqual(
            VirtualInterfaceCapability.evaluate(cannotWeakenBaseline),
            .unavailable(.unsupportedBuild)
        )
    }

    func testConfigurationValidationRejectsUnsafeValues() {
        XCTAssertNoThrow(try VirtualInterfaceConfiguration().validated())
        XCTAssertThrowsError(try VirtualInterfaceConfiguration(mtu: 128).validated()) { error in
            XCTAssertEqual(error as? VirtualInterfaceManagerError, .invalidMTU(128))
        }
        XCTAssertThrowsError(
            try VirtualInterfaceConfiguration(features: [.ipv4, .ipv6]).validated()
        ) { error in
            guard case .missingRequiredFeatures = error as? VirtualInterfaceManagerError else {
                return XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testUnavailableManagerFailsEnableAndMakesCleanupNoOps() async {
        let manager = UnavailableVirtualInterfaceManager(reason: .helperUnavailable)
        let capability = await manager.probe()
        XCTAssertEqual(capability, .unavailable(.helperUnavailable))
        let uiEnabled = await manager.isAvailableForUI
        XCTAssertFalse(uiEnabled)
        let initialStatus = await manager.status()
        XCTAssertEqual(initialStatus, .unavailable(.helperUnavailable))

        do {
            try await manager.enable(configuration: .init())
            XCTFail("enable must fail explicitly")
        } catch {
            XCTAssertEqual(
                error as? VirtualInterfaceManagerError,
                .unavailable(.helperUnavailable)
            )
        }

        try? await manager.disable()
        try? await manager.recoverIfNeeded()
        let finalStatus = await manager.status()
        XCTAssertEqual(finalStatus, .unavailable(.helperUnavailable))
    }

    func testCapabilityCodableRoundTrip() throws {
        let value = XrayRuntimeVersion(major: 26, minor: 7, patch: 11, prerelease: "rc1")
        let encoded = try JSONEncoder().encode(value)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), #""26.7.11-rc1""#)
        XCTAssertEqual(try JSONDecoder().decode(XrayRuntimeVersion.self, from: encoded), value)

        let features: VirtualInterfaceFeature = [.ipv4, .systemRouting, .crashRecovery]
        let featureData = try JSONEncoder().encode(features)
        XCTAssertEqual(try JSONDecoder().decode(VirtualInterfaceFeature.self, from: featureData), features)
    }
}
