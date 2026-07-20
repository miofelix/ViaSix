import Foundation

public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case overview
    case nodes
    case logs
    case settings

    public var id: Self { self }

    public var title: String {
        switch self {
        case .overview: "首页"
        case .nodes: "节点"
        case .logs: "日志"
        case .settings: "设置"
        }
    }

    public var subtitle: String {
        switch self {
        case .overview: "连接状态与网络控制"
        case .nodes: "测速并选择优选地址"
        case .logs: "查看代理与测速活动"
        case .settings: "服务器、本机与应用设置"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "house"
        case .nodes: "point.3.filled.connected.trianglepath.dotted"
        case .logs: "text.alignleft"
        case .settings: "gearshape"
        }
    }
}
