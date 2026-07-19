import Foundation

public enum AppMetadata {
    public static let name = "ViaSix"
    public static let defaultExitIPEndpoint = "https://api.myip.la/cn?json"
    public static let ipv4ExitIPEndpoint = "https://api-ipv4.ip.sb/ip"
    public static let ipv6ExitIPEndpoint = "https://api-ipv6.ip.sb/ip"
    public static let proxyHost = "127.0.0.1"
    public static let proxyPort = 11_451

    public static func exitIPEndpoint(
        for mode: ExitIPDetectionMode,
        automaticEndpoint: String
    ) -> String {
        switch mode {
        case .automatic: automaticEndpoint
        case .ipv4: ipv4ExitIPEndpoint
        case .ipv6: ipv6ExitIPEndpoint
        }
    }
}
