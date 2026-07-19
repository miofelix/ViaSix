import XCTest

@testable import ViaSixCore

final class ExitIPResponseParserTests: XCTestCase {
    func testParsesMyIPLAJSONResponse() throws {
        let data = Data(#"{"ip":"2606::1","location":{"country_name":"美国","city":"圣何塞"}}"#.utf8)
        XCTAssertEqual(
            try ExitIPResponseParser.parse(data),
            ExitIPInfo(ip: "2606::1", location: "圣何塞 美国")
        )
    }

    func testFallsBackToPlainIP() throws {
        XCTAssertEqual(
            try ExitIPResponseParser.parse(Data("1.1.1.1\n".utf8)),
            ExitIPInfo(ip: "1.1.1.1")
        )
    }

    func testReportsParsedAddressFamily() throws {
        let ipv4 = try ExitIPResponseParser.parse(Data("1.1.1.1".utf8))
        let ipv6 = try ExitIPResponseParser.parse(Data("2606::1".utf8))

        XCTAssertEqual(ipv4.addressFamily, .ipv4)
        XCTAssertEqual(ipv6.addressFamily, .ipv6)
    }

    func testDetectionModesResolveToFamilySpecificEndpoints() {
        let custom = "https://status.example.test/ip"

        XCTAssertEqual(
            AppMetadata.exitIPEndpoint(for: .automatic, automaticEndpoint: custom),
            custom
        )
        XCTAssertEqual(
            AppMetadata.exitIPEndpoint(for: .ipv4, automaticEndpoint: custom),
            AppMetadata.ipv4ExitIPEndpoint
        )
        XCTAssertEqual(
            AppMetadata.exitIPEndpoint(for: .ipv6, automaticEndpoint: custom),
            AppMetadata.ipv6ExitIPEndpoint
        )
    }

    func testRejectsWhitespaceOnlyResponse() {
        XCTAssertThrowsError(try ExitIPResponseParser.parse(Data(" \n".utf8)))
    }

    func testRejectsNonIPAddressTokens() {
        XCTAssertThrowsError(try ExitIPResponseParser.parse(Data("service-unavailable".utf8)))
        XCTAssertThrowsError(try ExitIPResponseParser.parse(Data(#"{"ip":"error"}"#.utf8)))
    }

    func testAcceptsPartialLocationPayload() throws {
        let data = Data(#"{"ip":"1.1.1.1","location":{"country_name":"澳大利亚"}}"#.utf8)
        XCTAssertEqual(
            try ExitIPResponseParser.parse(data),
            ExitIPInfo(ip: "1.1.1.1", location: "澳大利亚")
        )
    }

    func testParsesDetailedIPSBGeolocationResponse() throws {
        let data = Data(
            #"{"ip":"2606:0000:0000:0000:0000:0000:0000:0001","country":"中国","region":"山东","city":"青岛","organization":"China Telecom","isp":"China Telecom","asn":4134,"timezone":"Asia/Shanghai"}"#
                .utf8
        )

        XCTAssertEqual(
            try ExitIPGeolocationResponseParser.parse(data, expectedIP: "2606::1"),
            ExitIPInfo(
                ip: "2606::1",
                location: "中国 · 山东 · 青岛",
                details: "China Telecom · AS4134 · Asia/Shanghai"
            )
        )
    }

    func testGeolocationParserAcceptsMissingOptionalFields() throws {
        let data = Data(#"{"ip":"1.1.1.1","isp":"Example ISP"}"#.utf8)

        XCTAssertEqual(
            try ExitIPGeolocationResponseParser.parse(data, expectedIP: "1.1.1.1"),
            ExitIPInfo(ip: "1.1.1.1", details: "Example ISP")
        )
    }

    func testGeolocationParserRejectsMismatchedIP() {
        let data = Data(#"{"ip":"1.0.0.1","country":"澳大利亚"}"#.utf8)

        XCTAssertThrowsError(
            try ExitIPGeolocationResponseParser.parse(data, expectedIP: "1.1.1.1")
        ) { error in
            XCTAssertEqual(error as? ExitIPDetectionError, .invalidResponse)
        }
    }

    func testGeolocationParserRejectsInvalidJSON() {
        XCTAssertThrowsError(
            try ExitIPGeolocationResponseParser.parse(
                Data("service-unavailable".utf8),
                expectedIP: "1.1.1.1"
            )
        ) { error in
            XCTAssertEqual(error as? ExitIPDetectionError, .invalidResponse)
        }
    }

    func testExitIPInfoDecodesPayloadWithoutDetails() throws {
        let decoded = try JSONDecoder().decode(
            ExitIPInfo.self,
            from: Data(#"{"ip":"1.1.1.1","location":"澳大利亚"}"#.utf8)
        )

        XCTAssertEqual(decoded, ExitIPInfo(ip: "1.1.1.1", location: "澳大利亚"))
    }

    func testDetectorRejectsUnsupportedEndpointBeforeMakingRequest() async {
        let detector = ExitIPDetector()

        do {
            _ = try await detector.detect(endpoint: URL(string: "file:///tmp/exit-ip")!)
            XCTFail("Expected unsupported endpoint to be rejected")
        } catch {
            XCTAssertEqual(error as? ExitIPDetectionError, .invalidEndpoint)
        }
    }
}
