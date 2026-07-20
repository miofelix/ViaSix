import ServiceManagement
import ViaSixPrivilegedProtocol

enum TunHelperRegistrationState: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

struct TunHelperInstaller {
    private var service: SMAppService {
        SMAppService.daemon(plistName: TunHelperConstants.launchDaemonPlistName)
    }

    func status() -> TunHelperRegistrationState {
        Self.map(service.status)
    }

    @discardableResult
    func register() throws -> TunHelperRegistrationState {
        try service.register()
        return status()
    }

    @discardableResult
    func unregister() async throws -> TunHelperRegistrationState {
        try await service.unregister()
        return status()
    }

    @discardableResult
    func reregister() async throws -> TunHelperRegistrationState {
        switch service.status {
        case .enabled, .requiresApproval:
            try await service.unregister()
        case .notRegistered, .notFound:
            break
        @unknown default:
            break
        }
        try service.register()
        return status()
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func map(_ status: SMAppService.Status) -> TunHelperRegistrationState {
        switch status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }
}
