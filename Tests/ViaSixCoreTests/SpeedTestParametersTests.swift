import XCTest

@testable import ViaSixCore

final class SpeedTestParametersTests: XCTestCase {
    func testDefaultParametersProduceExpectedArguments() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-IP-\(UUID().uuidString).txt")
        try Data("2606:4700::/32\n".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let parameters = SpeedTestParameters(ipFile: fileURL.path)
        let args = try parameters.commandLineArguments(resultURL: URL(fileURLWithPath: "/tmp/result.csv"))

        XCTAssertEqual(Array(args.prefix(4)), ["-o", "/tmp/result.csv", "-tp", "443"])
        XCTAssertTrue(args.contains("-httping"))
        XCTAssertTrue(args.contains("-f"))
        XCTAssertTrue(args.contains(fileURL.path))
        XCTAssertTrue(args.contains("-tlr"))
    }

    func testCustomRangeTakesPriorityOverFile() throws {
        let parameters = SpeedTestParameters(ipFile: "/tmp/ipv6.txt", ipRange: "1.1.1.1,2606:4700::/32")
        let args = try parameters.commandLineArguments(resultURL: URL(fileURLWithPath: "/tmp/result.csv"))
        XCTAssertTrue(args.contains("-ip"))
        XCTAssertFalse(args.contains("-f"))
    }

    func testValidationRejectsInvalidPort() {
        let parameters = SpeedTestParameters(ipRange: "1.1.1.1", port: 65_536)
        XCTAssertThrowsError(try parameters.validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .outOfRange("端口应在 1 到 65535 之间"))
        }
    }

    func testValidationRejectsMissingAndEmptyIPFilesBeforeLaunch() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-missing-\(UUID().uuidString).txt")
        XCTAssertThrowsError(try SpeedTestParameters(ipFile: missingURL.path).validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .ipFileNotFound(missingURL.path))
        }

        let emptyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-empty-\(UUID().uuidString).txt")
        try Data().write(to: emptyURL)
        defer { try? FileManager.default.removeItem(at: emptyURL) }
        XCTAssertThrowsError(try SpeedTestParameters(ipFile: emptyURL.path).validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .ipFileEmpty(emptyURL.path))
        }
    }

    func testValidationRejectsSymbolicLinkIPFilesBeforeLaunch() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViaSix-IPLink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appendingPathComponent("outside.txt")
        let link = root.appendingPathComponent("ipv6.txt")
        try Data("2606:4700::1\n".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertThrowsError(try SpeedTestParameters(ipFile: link.path).validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .ipFileIsSymbolicLink(link.path))
        }
        // Directory is also not a usable IP list.
        XCTAssertThrowsError(try SpeedTestParameters(ipFile: root.path).validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .ipFileUnreadable(root.path))
        }
    }

    func testValidationRejectsMalformedIPRangesBeforeLaunch() {
        for value in [
            "not-an-ip",
            "1.1.1/24",
            "1.1.1.1/33",
            "2606:4700::/129",
            "fe80::1%en0/64",
            "1.1.1.1,",
        ] {
            XCTAssertThrowsError(try SpeedTestParameters(ipRange: value).validated()) { error in
                guard case .invalidIPRange = error as? SpeedTestParameterError else {
                    return XCTFail("Unexpected error for \(value): \(error)")
                }
            }
        }
    }

    func testValidationRejectsInvalidSpeedTestURLBeforeLaunch() {
        let parameters = SpeedTestParameters(
            ipRange: "1.1.1.1",
            url: "file:///tmp/payload"
        )
        XCTAssertThrowsError(try parameters.validated()) { error in
            XCTAssertEqual(error as? SpeedTestParameterError, .invalidURL)
        }
    }
}
