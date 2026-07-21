import Foundation
import XCTest

@testable import ViaSixMihomoConfig

final class MihomoRuntimeConfigurationTests: XCTestCase {
    func testRuleModeBuildsManagedGroupAndPrivateBypassRules() throws {
        let output = try sampleServer().runtimeConfiguration(
            options: MihomoRuntimeOptions(
                listenAddress: "127.0.0.1",
                mixedPort: 20_280,
                routingMode: .rule,
                logLevel: .info,
                ipv6Enabled: true,
                udpEnabled: true,
                sniffingEnabled: true,
                bypassPrivateNetworks: true
            ),
            replacingPrimaryServerWith: "1.1.1.1"
        )
        let root = try MihomoYAML.mapping(from: output)

        XCTAssertEqual(root.int("mixed-port"), 20_280)
        XCTAssertEqual(root.string("bind-address"), "127.0.0.1")
        XCTAssertEqual(root.string("mode"), "rule")
        XCTAssertEqual(root.string("log-level"), "info")
        XCTAssertEqual(root.bool("allow-lan"), false)
        XCTAssertEqual(root.mappings("proxies")?.first?.string("server"), "1.1.1.1")
        XCTAssertEqual(root.mappings("proxies")?.first?.bool("udp"), true)
        XCTAssertEqual(root.mappings("proxy-groups")?.first?.string("name"), "ViaSix")
        let rules = try XCTUnwrap(root["rules"] as? [String])
        XCTAssertTrue(rules.contains("IP-CIDR,192.168.0.0/16,DIRECT,no-resolve"))
        XCTAssertEqual(rules.last, "MATCH,ViaSix")
        XCTAssertEqual(root.mapping("tun")?.bool("enable"), false)
        XCTAssertEqual(root.mapping("sniffer")?.bool("enable"), true)
    }

    func testGlobalAndDirectModesUseMihomoNativeModeValues() throws {
        let server = try sampleServer()
        let global = try MihomoYAML.mapping(
            from: server.runtimeConfiguration(
                options: MihomoRuntimeOptions(routingMode: .global)
            )
        )
        XCTAssertEqual(global.string("mode"), "global")

        let direct = try MihomoYAML.mapping(
            from: MihomoServerConfiguration.runtimeConfiguration(
                server: server,
                options: MihomoRuntimeOptions(routingMode: .direct)
            )
        )
        XCTAssertEqual(direct.string("mode"), "direct")
        XCTAssertEqual(direct["rules"] as? [String], ["MATCH,DIRECT"])
        XCTAssertEqual(direct.mapping("tun")?.bool("enable"), false)
        XCTAssertNil(direct["proxies"])
        XCTAssertNil(direct["proxy-providers"])
        XCTAssertNil(direct["proxy-groups"])
    }

    func testUserProjectionNeverEnablesTunOrValidatesPrivilegedTunInput() throws {
        let output = try sampleServer().runtimeConfiguration(
            options: MihomoRuntimeOptions(
                tun: MihomoTunConfiguration(
                    mtu: 1,
                    routeExcludeAddresses: ["not-a-cidr"]
                )
            )
        )
        let root = try MihomoYAML.mapping(from: output)

        XCTAssertEqual(root.mapping("tun")?.bool("enable"), false)
        XCTAssertNil(root["dns"])
        XCTAssertEqual(root.mapping("profile")?.bool("store-fake-ip"), false)
    }

    func testPrivilegedTunUsesFixedRoutingAndFakeIPDNSWithoutDevice() throws {
        let output = try sampleServer().runtimeConfiguration(
            options: MihomoRuntimeOptions(
                routingMode: .rule,
                tun: MihomoTunConfiguration(
                    stack: .mixed,
                    strictRoute: true,
                    mtu: 1_500,
                    routeExcludeAddresses: ["1.1.1.1/32"]
                )
            ),
            projection: .privilegedTun
        )
        let root = try MihomoYAML.mapping(from: output)
        let tun: [String: Any] = try XCTUnwrap(root.mapping("tun"))
        let dns: [String: Any] = try XCTUnwrap(root.mapping("dns"))

        XCTAssertEqual(tun.bool("enable"), true)
        XCTAssertEqual(tun.string("stack"), "mixed")
        XCTAssertNil(tun["device"])
        XCTAssertEqual(tun.bool("auto-route"), true)
        XCTAssertEqual(tun.bool("strict-route"), true)
        XCTAssertEqual(tun.bool("auto-detect-interface"), true)
        XCTAssertEqual(tun["dns-hijack"] as? [String], ["any:53", "tcp://any:53"])
        XCTAssertEqual(tun["route-exclude-address"] as? [String], ["1.1.1.1/32"])
        XCTAssertEqual(dns.bool("enable"), true)
        XCTAssertEqual(dns.string("enhanced-mode"), "fake-ip")
        XCTAssertEqual(dns.string("fake-ip-range"), "198.18.0.1/16")
        XCTAssertEqual(dns.string("fake-ip-range6"), "fdfe:dcba:9876::1/64")
        XCTAssertEqual(dns.bool("respect-rules"), true)
        XCTAssertEqual(dns["default-nameserver"] as? [String], ["1.1.1.1", "8.8.8.8"])
        XCTAssertEqual(
            dns["nameserver"] as? [String],
            ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"]
        )
        XCTAssertEqual(
            dns["proxy-server-nameserver"] as? [String],
            ["https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"]
        )
        XCTAssertFalse(String(decoding: output, as: UTF8.self).contains("system"))
        XCTAssertEqual(root.mapping("profile")?.bool("store-fake-ip"), true)
    }

    func testPrivilegedTunRequiresExplicitTunConfiguration() throws {
        XCTAssertThrowsError(
            try sampleServer().runtimeConfiguration(
                options: MihomoRuntimeOptions(),
                projection: .privilegedTun
            )
        ) { error in
            XCTAssertEqual(error as? MihomoConfigurationError, .missingTunConfiguration)
        }
    }

    func testPrivilegedProjectionSupportsFourInlineProtocolsWithGroupsAndRules() throws {
        let output = try supportedProtocolsServer().runtimeConfiguration(
            options: privilegedOptions(),
            projection: .privilegedTun
        )
        let root = try MihomoYAML.mapping(from: output)

        XCTAssertEqual(
            root.mappings("proxies")?.compactMap { $0.string("type") },
            ["vless", "vmess", "trojan", "ss"]
        )
        XCTAssertEqual(root.mappings("proxy-groups")?.first?.string("name"), "PROXY")
        XCTAssertEqual((root["rules"] as? [String])?.last, "MATCH,PROXY")
        XCTAssertEqual(root.mapping("tun")?.bool("enable"), true)
        XCTAssertNotNil(root["dns"])
    }

    func testHTTPProvidersRemainCompatibleForUserProjectionButAreRejectedForPrivilege() throws {
        let server = try MihomoServerConfiguration(
            data: Data(
                """
                proxy-providers:
                  remote:
                    type: http
                    url: https://subscription.example/profile.yaml
                    path: ../../outside.yaml
                    interval: 3600
                proxy-groups:
                  - name: PROXY
                    type: select
                    use: [remote]
                rules:
                  - MATCH,PROXY
                """.utf8
            )
        )

        let userRoot = try MihomoYAML.mapping(
            from: server.runtimeConfiguration(options: MihomoRuntimeOptions())
        )
        XCTAssertEqual(
            userRoot.mapping("proxy-providers")?.mapping("remote")?.string("type"),
            "http"
        )
        XCTAssertEqual(userRoot.mapping("tun")?.bool("enable"), false)

        XCTAssertThrowsError(
            try server.runtimeConfiguration(
                options: privilegedOptions(),
                projection: .privilegedTun
            )
        ) { error in
            XCTAssertEqual(
                error as? MihomoConfigurationError,
                .unsupportedProviderType(name: "remote", type: "http")
            )
        }
    }

    func testInlineProxyAndRuleProvidersAreRebuiltFromSafeFields() throws {
        let server = try MihomoServerConfiguration(
            data: Data(
                """
                proxy-providers:
                  embedded:
                    type: inline
                    payload:
                      - name: provider-edge
                        type: ss
                        server: provider.example
                        port: 8388
                        cipher: aes-128-gcm
                        password: secret
                rule-providers:
                  local-domains:
                    type: inline
                    behavior: domain
                    payload:
                      - example.com
                proxy-groups:
                  - name: PROXY
                    type: select
                    use: [embedded]
                rules:
                  - RULE-SET,local-domains,PROXY
                  - MATCH,PROXY
                """.utf8
            )
        )

        let root = try MihomoYAML.mapping(
            from: server.runtimeConfiguration(
                options: privilegedOptions(),
                projection: .privilegedTun
            )
        )
        let provider = try XCTUnwrap(root.mapping("proxy-providers")?.mapping("embedded"))
        let payload = try XCTUnwrap(provider.mappings("payload"))
        XCTAssertEqual(provider.string("type"), "inline")
        XCTAssertEqual(payload.first?.string("type"), "ss")
        XCTAssertNil(payload.first?["path"])
        let ruleProvider = try XCTUnwrap(
            root.mapping("rule-providers")?.mapping("local-domains")
        )
        XCTAssertEqual(ruleProvider.string("type"), "inline")
        XCTAssertEqual(ruleProvider.string("behavior"), "domain")
        XCTAssertEqual(ruleProvider["payload"] as? [String], ["example.com"])
    }

    func testPrivilegedProjectionRejectsUnknownProtocolsAndDangerousProxyFields() throws {
        for profile in [
            """
            proxies:
              - name: unsupported
                type: socks5
                server: origin.example
                port: 1080
            """,
            """
            proxies:
              - name: plugin
                type: ss
                server: origin.example
                port: 8388
                cipher: aes-128-gcm
                password: secret
                plugin: obfs
                plugin-opts: {mode: tls}
            """,
            """
            proxies:
              - name: key-file
                type: vless
                server: origin.example
                port: 443
                uuid: 11111111-1111-4111-8111-111111111111
                network: ws
                tls: true
                servername: origin.example
                private-key: /tmp/key.pem
            """,
            """
            proxies:
              - name: nested-file
                type: vless
                server: origin.example
                port: 443
                uuid: 11111111-1111-4111-8111-111111111111
                network: ws
                tls: true
                servername: origin.example
                ws-opts:
                  path: /safe-request-path
                  certificate: /tmp/certificate.pem
            """,
        ] {
            let server = try MihomoServerConfiguration(data: Data(profile.utf8))
            XCTAssertThrowsError(
                try server.runtimeConfiguration(
                    options: privilegedOptions(),
                    projection: .privilegedTun
                ),
                profile
            )
        }
    }

    func testPrivilegedProjectionRejectsRemoteRuleProvidersAndGeodataRules() throws {
        let remoteProvider = try MihomoServerConfiguration(
            data: Data(
                """
                proxies:
                  - name: edge
                    type: ss
                    server: origin.example
                    port: 8388
                    cipher: aes-128-gcm
                    password: secret
                rule-providers:
                  remote:
                    type: http
                    behavior: domain
                    url: https://rules.example/rules.yaml
                    path: ../../rules.yaml
                rules:
                  - RULE-SET,remote,edge
                  - MATCH,edge
                """.utf8
            )
        )
        XCTAssertThrowsError(
            try remoteProvider.runtimeConfiguration(
                options: privilegedOptions(),
                projection: .privilegedTun
            )
        )

        let geodata = try MihomoServerConfiguration(
            data: Data(
                """
                proxies:
                  - name: edge
                    type: ss
                    server: origin.example
                    port: 8388
                    cipher: aes-128-gcm
                    password: secret
                rules:
                  - GEOIP,CN,DIRECT
                  - MATCH,edge
                """.utf8
            )
        )
        XCTAssertThrowsError(
            try geodata.runtimeConfiguration(
                options: privilegedOptions(),
                projection: .privilegedTun
            )
        )
    }

    func testPrivilegedProjectionRejectsUnsafeNamesNegativeAlterIDAndDuplicateGroups() throws {
        let profiles = [
            """
            proxy-providers:
              " provider ":
                type: inline
                payload:
                  - name: edge
                    type: ss
                    server: origin.example
                    port: 8388
                    cipher: aes-128-gcm
                    password: secret
            proxy-groups:
              - name: PROXY
                type: select
                use: [" provider "]
            rules:
              - MATCH,PROXY
            """,
            """
            proxies:
              - name: vmess-edge
                type: vmess
                server: origin.example
                port: 443
                uuid: 22222222-2222-4222-8222-222222222222
                alterId: -1
                cipher: auto
            """,
            """
            proxies:
              - name: edge
                type: ss
                server: origin.example
                port: 8388
                cipher: aes-128-gcm
                password: secret
            proxy-groups:
              - name: DUPLICATE
                type: select
                proxies: [edge]
              - name: DUPLICATE
                type: select
                proxies: [edge]
            rules:
              - MATCH,DUPLICATE
            """,
        ]

        for profile in profiles {
            let server = try MihomoServerConfiguration(data: Data(profile.utf8))
            XCTAssertThrowsError(
                try server.runtimeConfiguration(
                    options: privilegedOptions(),
                    projection: .privilegedTun
                ),
                profile
            )
        }
    }

    func testPrivilegedRuleLimitIsIndependentFromOrdinaryListLimit() throws {
        let rules =
            (0..<1_025).map { "DOMAIN-SUFFIX,host-\($0).example,edge" }
            + ["MATCH,edge"]
        let profile = """
            proxies:
              - name: edge
                type: ss
                server: origin.example
                port: 8388
                cipher: aes-128-gcm
                password: secret
            rules:
            \(rules.map { "  - \($0)" }.joined(separator: "\n"))
            """
        let server = try MihomoServerConfiguration(data: Data(profile.utf8))

        let root = try MihomoYAML.mapping(
            from: server.runtimeConfiguration(
                options: privilegedOptions(),
                projection: .privilegedTun
            )
        )
        XCTAssertEqual((root["rules"] as? [String])?.count, rules.count + 9)
    }

    func testPrivilegedTunValidatesMTUAndRouteExclusions() throws {
        for mtu in [1_279, 9_001] {
            XCTAssertThrowsError(
                try sampleServer().runtimeConfiguration(
                    options: privilegedOptions(tun: MihomoTunConfiguration(mtu: mtu)),
                    projection: .privilegedTun
                )
            ) { error in
                XCTAssertEqual(error as? MihomoConfigurationError, .invalidTunMTU)
            }
        }

        for mtu in [1_280, 9_000] {
            XCTAssertNoThrow(
                try sampleServer().runtimeConfiguration(
                    options: privilegedOptions(
                        tun: MihomoTunConfiguration(
                            mtu: mtu,
                            routeExcludeAddresses: ["1.1.1.1/32", "2001:db8::/32"]
                        )
                    ),
                    projection: .privilegedTun
                )
            )
        }

        for route in [
            "not-a-cidr",
            "127.0.0.1/32",
            "0.0.0.0/0",
            "198.18.0.0/15",
            "::1/128",
            "fdfe:dcba:9876::1/128",
        ] {
            XCTAssertThrowsError(
                try sampleServer().runtimeConfiguration(
                    options: privilegedOptions(
                        tun: MihomoTunConfiguration(routeExcludeAddresses: [route])
                    ),
                    projection: .privilegedTun
                ),
                route
            ) { error in
                XCTAssertEqual(
                    error as? MihomoConfigurationError,
                    .invalidTunRouteExclusion(route)
                )
            }
        }

        XCTAssertThrowsError(
            try sampleServer().runtimeConfiguration(
                options: privilegedOptions(
                    tun: MihomoTunConfiguration(
                        routeExcludeAddresses: (0..<33).map { "203.0.113.\($0)/32" }
                    )
                ),
                projection: .privilegedTun
            )
        ) { error in
            XCTAssertEqual(error as? MihomoConfigurationError, .tooManyTunRouteExclusions)
        }
    }

    func testRuntimeRejectsUnsafeLocalValuesAndAppliesUDPPreference() throws {
        XCTAssertThrowsError(
            try sampleServer().runtimeConfiguration(
                options: MihomoRuntimeOptions(listenAddress: "0.0.0.0")
            )
        ) { error in
            XCTAssertEqual(error as? MihomoConfigurationError, .invalidListenAddress)
        }

        let udpDisabled = try MihomoYAML.mapping(
            from: sampleServer().runtimeConfiguration(
                options: MihomoRuntimeOptions(udpEnabled: false)
            )
        )
        XCTAssertEqual(udpDisabled.mappings("proxies")?.first?.bool("udp"), false)
    }

    func testPrivilegedConfigurationPassesPinnedMihomoValidationWhenAvailable() throws {
        guard
            let binary = ProcessInfo.processInfo.environment["VIASIX_MIHOMO_TEST_BINARY"],
            FileManager.default.isExecutableFile(atPath: binary)
        else {
            throw XCTSkip("Set VIASIX_MIHOMO_TEST_BINARY to run the real-core validation")
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ViaSixMihomoRuntimeTests-\(UUID().uuidString)",
            isDirectory: true
        )
        let home = root.appendingPathComponent("home", isDirectory: true)
        let config = root.appendingPathComponent("config.yaml")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try supportedProtocolsServer().runtimeConfiguration(
            options: privilegedOptions(),
            projection: .privilegedTun
        ).write(to: config)

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["-t", "-d", home.path, "-f", config.path]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let diagnostics = String(
            decoding: output.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        )
        XCTAssertEqual(process.terminationStatus, 0, diagnostics)
    }

    private func privilegedOptions(
        tun: MihomoTunConfiguration = MihomoTunConfiguration()
    ) -> MihomoRuntimeOptions {
        MihomoRuntimeOptions(
            routingMode: .rule,
            ipv6Enabled: true,
            udpEnabled: true,
            sniffingEnabled: true,
            bypassPrivateNetworks: true,
            tun: tun
        )
    }

    private func sampleServer() throws -> MihomoServerConfiguration {
        try MihomoServerConfiguration(
            profile: MihomoProxyProfile(
                name: "edge",
                protocolName: .vless,
                serverAddress: "origin.example.com",
                serverPort: 443,
                credential: "11111111-1111-4111-8111-111111111111",
                transport: .websocket,
                security: .tls,
                serverName: "origin.example.com",
                host: "origin.example.com"
            )
        )
    }

    private func supportedProtocolsServer() throws -> MihomoServerConfiguration {
        try MihomoServerConfiguration(
            data: Data(
                """
                proxies:
                  - name: vless-edge
                    type: vless
                    server: vless.example
                    port: 443
                    uuid: 11111111-1111-4111-8111-111111111111
                    encryption: none
                    network: ws
                    tls: true
                    servername: vless.example
                    ws-opts:
                      path: /proxy
                      headers:
                        Host: vless.example
                  - name: vmess-edge
                    type: vmess
                    server: vmess.example
                    port: 443
                    uuid: 22222222-2222-4222-8222-222222222222
                    alterId: 0
                    cipher: auto
                    network: grpc
                    tls: true
                    servername: vmess.example
                    grpc-opts:
                      grpc-service-name: viasix
                  - name: trojan-edge
                    type: trojan
                    server: trojan.example
                    port: 443
                    password: trojan-secret
                    network: tcp
                    sni: trojan.example
                  - name: ss-edge
                    type: ss
                    server: ss.example
                    port: 8388
                    cipher: aes-128-gcm
                    password: ss-secret
                proxy-groups:
                  - name: PROXY
                    type: select
                    proxies: [vless-edge, vmess-edge, trojan-edge, ss-edge]
                rules:
                  - DOMAIN-SUFFIX,example.com,PROXY
                  - MATCH,PROXY
                """.utf8
            )
        )
    }
}
