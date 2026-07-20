import ViaSixCore
import XCTest

@testable import ViaSixApp

final class XrayTemplateEditorTests: XCTestCase {
    func testDraftAnalysisReportsEndpointForLaunchReadyConfiguration() {
        let analysis = XrayTemplateDraftAnalysis.inspect(
            validTemplate(),
            selectedIP: "2606:4700::1111"
        )

        XCTAssertEqual(
            analysis.status,
            .valid(ProxyEndpoint(host: "127.0.0.2", port: 18_081))
        )
        XCTAssertTrue(analysis.isValid)
        XCTAssertTrue(analysis.canFormat)
        XCTAssertNil(analysis.issue)
    }

    func testDraftAnalysisDistinguishesValidTemplateWithoutSelectedNode() {
        let analysis = XrayTemplateDraftAnalysis.inspect(
            validTemplate(),
            selectedIP: ""
        )

        XCTAssertEqual(
            analysis.status,
            .validWithoutNode(ProxyEndpoint(host: "127.0.0.2", port: 18_081))
        )
        XCTAssertEqual(analysis.statusTitle, "配置有效，待选择节点")
        XCTAssertTrue(analysis.isValid)
    }

    func testDraftAnalysisDistinguishesJSONAndConfigurationErrors() {
        let malformed = XrayTemplateDraftAnalysis.inspect("{", selectedIP: nil)
        XCTAssertEqual(
            malformed.status,
            .invalidJSON(ConfigTemplateError.invalidJSON.localizedDescription)
        )
        XCTAssertFalse(malformed.canFormat)

        let missingOutbounds = XrayTemplateDraftAnalysis.inspect(
            #"{"inbounds": []}"#,
            selectedIP: nil
        )
        XCTAssertEqual(
            missingOutbounds.status,
            .invalidConfiguration(ConfigTemplateError.invalidLocalInbound.localizedDescription)
        )
        XCTAssertTrue(missingOutbounds.canFormat)
    }

    func testDraftAnalysisRejectsPlaceholderCredentialsBeforeSave() {
        let placeholder = validTemplate(
            userID: ConfigTemplate.placeholderUserID,
            serverName: ConfigTemplate.placeholderServerName
        )
        let analysis = XrayTemplateDraftAnalysis.inspect(
            placeholder,
            selectedIP: "2606:4700::1111"
        )

        XCTAssertEqual(
            analysis.status,
            .invalidConfiguration(ConfigTemplateError.connectionNotConfigured.localizedDescription)
        )
        XCTAssertFalse(analysis.isValid)
        XCTAssertTrue(analysis.canFormat)
    }

    func testFormattingUsesStableReadableJSONAndKeepsURLsReadable() throws {
        let formatted = try XrayTemplateDraftAnalysis.formatted(
            #"{"z":"https:\/\/example.com/path","a":1}"#
        )

        XCTAssertEqual(
            formatted,
            """
            {
              "a" : 1,
              "z" : "https://example.com/path"
            }

            """
        )
    }

    private func validTemplate(
        userID: String = "7b602ceb-cc3f-4274-a79d-c1a38f0fb0da",
        serverName: String = "proxy.example.net"
    ) -> String {
        #"""
        {
          "inbounds": [{"listen": "127.0.0.2", "port": 18081, "protocol": "mixed"}],
          "outbounds": [{
            "tag": "proxy",
            "settings": {"vnext": [{
              "address": "2001:db8::10",
              "users": [{"id": "\#(userID)"}]
            }]},
            "streamSettings": {
              "tlsSettings": {"serverName": "\#(serverName)"},
              "wsSettings": {"host": "\#(serverName)", "path": "/viasix"}
            }
          }]
        }
        """#
    }
}
