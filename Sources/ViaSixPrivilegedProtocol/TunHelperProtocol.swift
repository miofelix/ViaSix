import Foundation

public enum TunHelperConstants {
    public static let appBundleIdentifier = "com.felix.viasix"
    public static let helperBundleIdentifier = "com.felix.viasix.tun-helper"
    public static let machServiceName = helperBundleIdentifier
    public static let launchDaemonPlistName = "\(helperBundleIdentifier).plist"
    public static let protocolVersion = 1
    public static let implementationVersion = 1
}

/// The privileged surface is deliberately small and uses fixed methods only.
/// It must never grow an arbitrary shell, path, argv, or JSON execution API.
@objc public protocol TunHelperXPCProtocol {
    func probe(
        reply:
            @escaping (
                _ protocolVersion: Int,
                _ implementationVersion: Int,
                _ supportedFeatures: UInt64,
                _ recoveryPending: Bool,
                _ error: NSError?
            ) -> Void
    )

    func recoverIfNeeded(reply: @escaping (_ error: NSError?) -> Void)
}

public struct TunHelperProbeResult: Equatable, Sendable {
    public let protocolVersion: Int
    public let implementationVersion: Int
    public let supportedFeatures: UInt64
    public let recoveryPending: Bool

    public init(
        protocolVersion: Int,
        implementationVersion: Int,
        supportedFeatures: UInt64,
        recoveryPending: Bool
    ) {
        self.protocolVersion = protocolVersion
        self.implementationVersion = implementationVersion
        self.supportedFeatures = supportedFeatures
        self.recoveryPending = recoveryPending
    }
}

public enum TunHelperClientError: LocalizedError, Equatable, Sendable {
    case incompatibleProtocol(expected: Int, actual: Int)
    case invalidRemoteObject
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .incompatibleProtocol(let expected, let actual):
            "虚拟网卡服务协议不兼容（需要 \(expected)，实际 \(actual)）"
        case .invalidRemoteObject:
            "无法连接虚拟网卡服务"
        case .timedOut:
            "虚拟网卡服务响应超时"
        }
    }
}
