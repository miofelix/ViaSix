import Foundation

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case overview
    case nodes
    case profiles
    case logs
    case settings

    public var id: Self { self }

    public var title: String {
        switch self {
        case .overview: "首页"
        case .profiles: "连接配置"
        case .logs: "日志"
        case .nodes: "IPv6 优选"
        case .settings: "设置"
        }
    }

    public var subtitle: String {
        switch self {
        case .overview: "IPv6 链路状态与控制"
        case .profiles: "管理 IPv6 代理入口配置"
        case .logs: "查看代理与测速活动"
        case .nodes: "测速并选择 IPv6 地址"
        case .settings: "服务器、本机与应用设置"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "house"
        case .profiles: "shippingbox"
        case .logs: "text.alignleft"
        case .nodes: "point.3.filled.connected.trianglepath.dotted"
        case .settings: "gearshape"
        }
    }
}
