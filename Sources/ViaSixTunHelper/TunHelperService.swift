import Foundation
import ViaSixPrivilegedProtocol
import ViaSixTunHelperSupport

final class TunHelperService: NSObject, TunHelperXPCProtocol {
    private let clientUserIdentifier: UInt32
    private let journalController: TunSessionJournalController

    init(
        clientUserIdentifier: UInt32,
        journalController: TunSessionJournalController
    ) {
        self.clientUserIdentifier = clientUserIdentifier
        self.journalController = journalController
    }

    func probe(
        reply: @escaping (Int, Int, UInt64, Bool, NSError?) -> Void
    ) {
        // Phase one intentionally advertises no network mutation capability.
        // Features are enabled only after their concrete, recoverable backend
        // and isolated-system tests exist.
        do {
            let recoveryPending = try journalController.recoveryPending()
            reply(
                TunHelperConstants.protocolVersion,
                TunHelperConstants.implementationVersion,
                0,
                recoveryPending,
                nil
            )
        } catch {
            reply(
                TunHelperConstants.protocolVersion,
                TunHelperConstants.implementationVersion,
                0,
                false,
                error as NSError
            )
        }
    }

    func recoverIfNeeded(reply: @escaping (NSError?) -> Void) {
        do {
            // Recovery is intentionally safe for any authenticated ViaSix
            // client. A later start/stop surface will bind mutation leases to
            // clientUserIdentifier, while stale cleanup must remain possible
            // after logout or a fast-user switch.
            _ = clientUserIdentifier
            try journalController.recoverIfNeeded()
            reply(nil)
        } catch {
            reply(error as NSError)
        }
    }
}
