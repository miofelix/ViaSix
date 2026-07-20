import Darwin
import Foundation
import XCTest

@testable import ViaSixTunHelperSupport

final class TunSessionJournalTests: XCTestCase {
    func testAtomicRoundTripUsesPrivatePermissionsAndRemovalIsIdempotent() throws {
        try withStore { store, root in
            let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
            let journal = TunSessionJournal(
                ownerUserIdentifier: UInt32(geteuid()),
                phase: .running,
                cleanupRequired: true,
                createdAt: createdAt
            )

            try store.save(journal)
            XCTAssertEqual(try store.load(), journal)

            let directoryMode = try fileMode(at: root)
            let journalMode = try fileMode(at: root.appendingPathComponent("tun-session.json"))
            XCTAssertEqual(directoryMode & 0o777, 0o700)
            XCTAssertEqual(journalMode & 0o777, 0o600)

            try store.remove()
            try store.remove()
            XCTAssertNil(try store.load())
        }
    }

    func testLoadRejectsSymbolicLinkJournal() throws {
        try withStore { store, root in
            _ = try store.load()
            let target = root.deletingLastPathComponent().appendingPathComponent("outside.json")
            try Data("{}".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(
                at: root.appendingPathComponent("tun-session.json"),
                withDestinationURL: target
            )

            XCTAssertThrowsError(try store.load()) { error in
                guard case .posix(let operation, let code) = error as? TunSessionJournalError else {
                    return XCTFail("Unexpected error: \(error)")
                }
                XCTAssertEqual(operation, "openat(journal)")
                XCTAssertEqual(code, ELOOP)
            }
        }
    }

    func testControllerTransitionsAndClearsCompletedSession() throws {
        try withStore { store, _ in
            let controller = TunSessionJournalController(
                store: store,
                now: { Date(timeIntervalSince1970: 1_700_000_000) }
            )
            let preparing = try controller.begin(ownerUserIdentifier: UInt32(geteuid()))
            XCTAssertTrue(try controller.recoveryPending())

            let running = try controller.markRunning(
                sessionIdentifier: preparing.sessionIdentifier
            )
            XCTAssertEqual(running.phase, .running)

            try controller.complete(sessionIdentifier: preparing.sessionIdentifier)
            XCTAssertFalse(try controller.recoveryPending())
            XCTAssertNil(try controller.currentJournal())
        }
    }

    func testRecoveryPersistsFailureAndCanBeRetried() throws {
        enum CleanupError: LocalizedError {
            case failed

            var errorDescription: String? { "cleanup failed" }
        }

        try withStore { store, _ in
            let controller = TunSessionJournalController(store: store)
            _ = try controller.begin(ownerUserIdentifier: UInt32(geteuid()))

            XCTAssertThrowsError(
                try controller.recoverIfNeeded { _ in throw CleanupError.failed }
            )
            let failed = try XCTUnwrap(controller.currentJournal())
            XCTAssertEqual(failed.phase, .failed)
            XCTAssertTrue(failed.recoveryPending)
            XCTAssertEqual(failed.lastError, "cleanup failed")

            try controller.recoverIfNeeded()
            XCTAssertNil(try controller.currentJournal())
        }
    }

    func testStaleSessionCannotChangeNewJournal() throws {
        try withStore { store, _ in
            let controller = TunSessionJournalController(store: store)
            let current = try controller.begin(ownerUserIdentifier: UInt32(geteuid()))
            let stale = UUID()

            XCTAssertThrowsError(try controller.markRunning(sessionIdentifier: stale)) { error in
                XCTAssertEqual(
                    error as? TunSessionJournalError,
                    .staleSession(expected: stale, actual: current.sessionIdentifier)
                )
            }
        }
    }

    private func withStore(
        _ body: (TunSessionJournalStore, URL) throws -> Void
    ) throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ViaSix-TunJournal-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = parent.appendingPathComponent("State", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: parent) }

        let store = TunSessionJournalStore(
            rootDirectoryURL: root,
            expectedOwnerUserIdentifier: UInt32(geteuid())
        )
        try body(store, root)
    }

    private func fileMode(at url: URL) throws -> mode_t {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return metadata.st_mode
    }
}
