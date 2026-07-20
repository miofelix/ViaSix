import Foundation
import ViaSixPrivilegedProtocol

actor TunHelperClient {
    private static let responseTimeout: Duration = .seconds(5)
    private var connection: NSXPCConnection?

    func probe() async throws -> TunHelperProbeResult {
        let connection = try connectionForUse()
        return try await withCheckedThrowingContinuation { continuation in
            let gate = ContinuationGate(continuation)
            scheduleTimeout(for: gate)
            let remote = connection.remoteObjectProxyWithErrorHandler { error in
                gate.resume(throwing: error)
            }
            guard let helper = remote as? TunHelperXPCProtocol else {
                gate.resume(throwing: TunHelperClientError.invalidRemoteObject)
                return
            }
            helper.probe {
                protocolVersion,
                implementationVersion,
                supportedFeatures,
                recoveryPending,
                error in
                if let error {
                    gate.resume(throwing: error)
                    return
                }
                guard protocolVersion == TunHelperConstants.protocolVersion else {
                    gate.resume(
                        throwing: TunHelperClientError.incompatibleProtocol(
                            expected: TunHelperConstants.protocolVersion,
                            actual: protocolVersion
                        )
                    )
                    return
                }
                gate.resume(
                    returning: TunHelperProbeResult(
                        protocolVersion: protocolVersion,
                        implementationVersion: implementationVersion,
                        supportedFeatures: supportedFeatures,
                        recoveryPending: recoveryPending
                    )
                )
            }
        }
    }

    func recoverIfNeeded() async throws {
        let connection = try connectionForUse()
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let gate = ContinuationGate(continuation)
            scheduleTimeout(for: gate)
            let remote = connection.remoteObjectProxyWithErrorHandler { error in
                gate.resume(throwing: error)
            }
            guard let helper = remote as? TunHelperXPCProtocol else {
                gate.resume(throwing: TunHelperClientError.invalidRemoteObject)
                return
            }
            helper.recoverIfNeeded { error in
                if let error {
                    gate.resume(throwing: error)
                } else {
                    gate.resume(returning: ())
                }
            }
        }
    }

    func invalidate() {
        connection?.invalidate()
        connection = nil
    }

    private func connectionForUse() throws -> NSXPCConnection {
        if let connection { return connection }

        let identity = try CodeSigningInspector.currentProcess(
            expectedIdentifier: TunHelperConstants.appBundleIdentifier
        )
        let helperRequirement = try CodeSigningRequirementBuilder.sameTeamRequirement(
            identifier: TunHelperConstants.helperBundleIdentifier,
            teamIdentifier: identity.teamIdentifier
        )
        let connection = NSXPCConnection(
            machServiceName: TunHelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: TunHelperXPCProtocol.self)
        connection.setCodeSigningRequirement(helperRequirement)
        connection.activate()
        self.connection = connection
        return connection
    }

    private nonisolated func scheduleTimeout<Value>(
        for gate: ContinuationGate<Value>
    ) where Value: Sendable {
        Task {
            try? await Task.sleep(for: Self.responseTimeout)
            gate.resume(throwing: TunHelperClientError.timedOut)
        }
    }
}

private final class ContinuationGate<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = continuation
    }

    func resume(returning value: sending Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: any Error) {
        take()?.resume(throwing: error)
    }

    private func take() -> CheckedContinuation<Value, any Error>? {
        lock.lock()
        defer { lock.unlock() }
        let current = continuation
        continuation = nil
        return current
    }
}
