import Foundation

struct ClientIdentityValidator {
    func validatedUserIdentifier(for connection: NSXPCConnection) -> UInt32? {
        // The listener's code-signing requirement is the primary identity
        // boundary. These checks reject invalid/system contexts before an
        // exported object is attached and avoid treating PID alone as identity.
        guard
            connection.processIdentifier > 1,
            connection.effectiveUserIdentifier > 0,
            connection.auditSessionIdentifier > 0
        else { return nil }
        return connection.effectiveUserIdentifier
    }
}
