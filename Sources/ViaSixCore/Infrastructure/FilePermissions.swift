import Darwin
import Foundation

enum FilePermissionsError: LocalizedError, Equatable, Sendable {
    case missing(URL)
    case isSymbolicLink(URL)
    case unexpectedType(URL, expected: String)
    case permissionChangeFailed(URL)

    var errorDescription: String? {
        switch self {
        case .missing(let url):
            "路径不存在，无法设置权限：\(url.path)"
        case .isSymbolicLink(let url):
            "不能通过符号链接设置权限：\(url.path)"
        case .unexpectedType(let url, let expected):
            "路径不是\(expected)，无法设置权限：\(url.path)"
        case .permissionChangeFailed(let url):
            "设置路径权限失败：\(url.path)"
        }
    }
}

/// Restricts ownership-sensitive paths without following symbolic links.
///
/// `FileManager.setAttributes` follows links and would otherwise chmod the
/// link target. Credentials, preferences, and configuration live under these
/// paths, so a planted symlink must fail closed instead of mutating an
/// attacker-chosen file or directory.
enum FilePermissions {
    static func restrictDirectory(_ url: URL, using fileManager: FileManager = .default) throws {
        try ensurePath(url, expectedType: S_IFDIR, expectedDescription: "目录")
        do {
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        } catch {
            throw FilePermissionsError.permissionChangeFailed(url)
        }
    }

    static func restrictFile(_ url: URL, using fileManager: FileManager = .default) throws {
        try ensurePath(url, expectedType: S_IFREG, expectedDescription: "普通文件")
        do {
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            throw FilePermissionsError.permissionChangeFailed(url)
        }
    }

    private static func ensurePath(
        _ url: URL,
        expectedType: mode_t,
        expectedDescription: String
    ) throws {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            throw FilePermissionsError.missing(url)
        }

        let fileType = metadata.st_mode & S_IFMT
        guard fileType != S_IFLNK else {
            throw FilePermissionsError.isSymbolicLink(url)
        }
        guard fileType == expectedType else {
            throw FilePermissionsError.unexpectedType(url, expected: expectedDescription)
        }
    }
}
