import Darwin
import Foundation
import XCTest

@testable import ViaSixCore

final class FilePermissionsTests: XCTestCase {
    func testRestrictFileSetsOwnerOnlyModeOnRegularFile() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("secret.txt")
        try Data("token".utf8).write(to: fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: fileURL.path
        )

        try FilePermissions.restrictFile(fileURL)

        XCTAssertEqual(try permissions(of: fileURL), 0o600)
        XCTAssertFalse(isSymbolicLink(fileURL))
    }

    func testRestrictDirectorySetsOwnerOnlyModeOnDirectory() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directoryURL = root.appendingPathComponent("Data", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: directoryURL.path
        )

        try FilePermissions.restrictDirectory(directoryURL)

        XCTAssertEqual(try permissions(of: directoryURL), 0o700)
        XCTAssertFalse(isSymbolicLink(directoryURL))
    }

    func testRestrictFileRejectsSymbolicLinkWithoutChangingTargetMode() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let targetURL = root.appendingPathComponent("outside-secret.txt")
        let linkURL = root.appendingPathComponent("controller.secret")
        try Data("sensitive".utf8).write(to: targetURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: targetURL.path
        )
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        XCTAssertThrowsError(try FilePermissions.restrictFile(linkURL)) { error in
            XCTAssertEqual(error as? FilePermissionsError, .isSymbolicLink(linkURL))
        }

        XCTAssertEqual(try permissions(of: targetURL), 0o644)
        XCTAssertTrue(isSymbolicLink(linkURL))
    }

    func testRestrictDirectoryRejectsSymbolicLinkWithoutChangingTargetMode() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let targetURL = root.appendingPathComponent("outside-data", isDirectory: true)
        let linkURL = root.appendingPathComponent("Data", isDirectory: true)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: targetURL.path
        )
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: targetURL)

        XCTAssertThrowsError(try FilePermissions.restrictDirectory(linkURL)) { error in
            XCTAssertEqual(error as? FilePermissionsError, .isSymbolicLink(linkURL))
        }

        XCTAssertEqual(try permissions(of: targetURL), 0o755)
        XCTAssertTrue(isSymbolicLink(linkURL))
    }

    func testRestrictFileRejectsDirectoryAndRestrictDirectoryRejectsFile() throws {
        let root = makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directoryURL = root.appendingPathComponent("dir", isDirectory: true)
        let fileURL = root.appendingPathComponent("file.txt")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("payload".utf8).write(to: fileURL)

        XCTAssertThrowsError(try FilePermissions.restrictFile(directoryURL)) { error in
            XCTAssertEqual(
                error as? FilePermissionsError,
                .unexpectedType(directoryURL, expected: "普通文件")
            )
        }
        XCTAssertThrowsError(try FilePermissions.restrictDirectory(fileURL)) { error in
            XCTAssertEqual(
                error as? FilePermissionsError,
                .unexpectedType(fileURL, expected: "目录")
            )
        }
    }

    func testAppPathsPrepareFailsClosedWhenDataDirectoryIsSymbolicLink() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FilePermissions-AppPaths-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let outside = root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: outside.path
        )

        let appRoot = root.appendingPathComponent("ViaSix", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        let dataLink = appRoot.appendingPathComponent("Data", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: dataLink, withDestinationURL: outside)

        let paths = AppPaths(root: appRoot)
        XCTAssertThrowsError(try paths.prepare()) { error in
            XCTAssertEqual(error as? FilePermissionsError, .isSymbolicLink(paths.data))
        }
        XCTAssertEqual(try permissions(of: outside), 0o755)
    }

    private func makeRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FilePermissionsTests-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func permissions(of url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue & 0o777
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else { return false }
        return (metadata.st_mode & S_IFMT) == S_IFLNK
    }
}
