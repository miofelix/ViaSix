import Foundation
import OSLog
import ViaSixPrivilegedProtocol
import ViaSixTunHelperSupport

private let logger = Logger(
    subsystem: TunHelperConstants.helperBundleIdentifier,
    category: "Lifecycle"
)

do {
    let identity = try CodeSigningInspector.currentProcess(
        expectedIdentifier: TunHelperConstants.helperBundleIdentifier
    )
    let clientRequirement = try CodeSigningRequirementBuilder.sameTeamRequirement(
        identifier: TunHelperConstants.appBundleIdentifier,
        teamIdentifier: identity.teamIdentifier
    )

    let journalController = TunSessionJournalController()
    do {
        try journalController.recoverIfNeeded()
    } catch {
        // Keep the authenticated recovery endpoint available so the app can
        // surface the failure and retry instead of making a stale journal
        // impossible to repair without manual filesystem work.
        logger.error(
            "Initial TUN recovery failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    let delegate = TunXPCListener(journalController: journalController)
    let listener = NSXPCListener(machServiceName: TunHelperConstants.machServiceName)
    listener.setConnectionCodeSigningRequirement(clientRequirement)
    listener.delegate = delegate
    listener.activate()
    logger.info("ViaSix TUN helper is ready")
    RunLoop.current.run()
} catch {
    logger.fault("ViaSix TUN helper refused to start: \(error.localizedDescription, privacy: .public)")
    exit(EXIT_FAILURE)
}
