import AppKit
import Network
import SwiftUI
import ViaSixCore

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    let onSelectNodes: () -> Void
    let onManageRuntime: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppPageHeader("首页", subtitle: "IPv6 代理链路状态与控制") {
                StatusBadge(
                    headerStatus,
                    tone: headerTone,
                    systemImage: headerIcon
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: VisualStyle.spacing12) {
                    if !model.usesIPv6RequiredTransport {
                        compatibilityBanner
                    }
                    ipv6LinkCard
                    HStack(alignment: .top, spacing: VisualStyle.spacing12) {
                        nodeCard
                        exitIPCard
                    }
                    if !model.usesIPv6RequiredTransport,
                        let groups = model.state.mihomoRuntime.snapshot?.proxyGroups,
                        !groups.isEmpty
                    {
                        proxySelectionCard(groups)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VisualStyle.pageHorizontalPadding)
                .padding(.vertical, VisualStyle.pageVerticalPadding)
            }
            .scrollbarSafeContent()
        }
    }

    private var compatibilityBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("兼容模式未保证 IPv6 代理链路")
                    .font(.callout.weight(.semibold))
                Text("当前可使用 IPv4、Provider、导入规则或系统代理。切换回 IPv6 模式后，ViaSix 会要求 TUN、IPv6 节点和可注入的内联配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("打开设置", action: onManageRuntime)
        }
        .padding(VisualStyle.spacing16)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.25)))
    }

    private var ipv6LinkCard: some View {
        SurfaceCard {
            CardHeader("IPv6 链路", systemImage: "6.circle.fill", tone: headerTone) {
                proxyActionButton
            }
            Divider()

            VStack(spacing: 0) {
                linkStep(
                    "虚拟网卡",
                    detail: tunDetail,
                    ready: model.canUseTunMode,
                    active: model.state.tun.isRunning,
                    actionTitle: model.canUseTunMode ? nil : "准备服务",
                    action: onManageRuntime
                )
                Divider().padding(.leading, 52)
                linkStep(
                    "IPv6 节点",
                    detail: selectedNodeDetail,
                    ready: selectedNodeIsIPv6,
                    active: selectedNodeIsIPv6,
                    actionTitle: selectedNodeIsIPv6 ? "更换" : "选择",
                    action: onSelectNodes
                )
                Divider().padding(.leading, 52)
                linkStep(
                    "连接配置",
                    detail: configurationDetail,
                    ready: model.state.proxySupportsNodeSelection,
                    active: model.state.proxySupportsNodeSelection,
                    actionTitle: nil,
                    action: nil
                )
                Divider().padding(.leading, 52)
                linkStep(
                    "公网流量",
                    detail: publicTrafficDetail,
                    ready: model.isProxyConfigurationReady,
                    active: model.state.isProxyRunning,
                    actionTitle: nil,
                    action: nil
                )
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
    }

    private func linkStep(
        _ title: String,
        detail: String,
        ready: Bool,
        active: Bool,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        SettingRow(
            title,
            detail: detail,
            systemImage: active ? "checkmark.circle.fill" : (ready ? "checkmark.circle" : "circle")
        ) {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            } else {
                StatusBadge(
                    active ? "已启用" : (ready ? "已就绪" : "未就绪"),
                    tone: active ? .positive : (ready ? .accent : .warning)
                )
            }
        }
    }

    private var nodeCard: some View {
        SurfaceCard {
            CardHeader("当前 IPv6 节点", systemImage: "network", tone: selectedNodeIsIPv6 ? .accent : .warning)
            Divider()
            VStack(alignment: .leading, spacing: VisualStyle.spacing12) {
                Text(model.state.preferences.selectedIP.isEmpty ? "尚未选择" : model.state.preferences.selectedIP)
                    .font(.title3.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if let result = currentNodeResult {
                    Text(result.performanceSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("选择 IPv6 优选地址后，ViaSix 会在运行时将它注入代理入口。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("选择节点", systemImage: "list.bullet", action: onSelectNodes)
                    Button(configurationTestTitle, systemImage: "scope") {
                        if configurationTestIsRunning {
                            model.stopCurrentConfigurationTest()
                        } else {
                            model.startCurrentConfigurationTest()
                        }
                    }
                    .disabled(
                        !configurationTestIsRunning
                            && model.currentConfigurationTestUnavailableReason != nil
                    )
                }
            }
            .padding(VisualStyle.spacing16)
        }
        .frame(maxWidth: .infinity)
    }

    private var exitIPCard: some View {
        SurfaceCard {
            CardHeader("公网出口", systemImage: "location", tone: .neutral)
            Divider()
            VStack(alignment: .leading, spacing: VisualStyle.spacing12) {
                HStack {
                    Text(model.state.exit.info?.ip ?? "尚未检测")
                        .font(.title3.monospaced().weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    if model.state.exit.info != nil {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                model.state.exit.info?.ip ?? "",
                                forType: .string
                            )
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if let info = model.state.exit.info, !info.location.isEmpty {
                    Text(info.location)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("出口地址可能是 IPv4；它不代表客户端到代理入口所使用的地址族。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Picker("地址族", selection: exitModeBinding) {
                        Text("自动").tag(ExitIPDetectionMode.automatic)
                        Text("IPv4").tag(ExitIPDetectionMode.ipv4)
                        Text("IPv6").tag(ExitIPDetectionMode.ipv6)
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    Button(
                        model.state.exit.isDetecting ? "检测中…" : "检测",
                        systemImage: "arrow.clockwise",
                        action: model.detectExitIP
                    )
                    .disabled(model.state.exit.isDetecting)
                }
            }
            .padding(VisualStyle.spacing16)
        }
        .frame(maxWidth: .infinity)
    }

    private func proxySelectionCard(_ groups: [MihomoProxyGroup]) -> some View {
        SurfaceCard {
            CardHeader("兼容模式代理组", systemImage: "wifi", tone: .warning) {
                Button("刷新", systemImage: "arrow.clockwise", action: model.refreshMihomoRuntime)
                    .controlSize(.small)
                    .disabled(model.isMihomoActionBusy)
            }
            Divider()
            VStack(spacing: 0) {
                ForEach(groups) { group in
                    SettingRow(group.name, detail: "本次运行有效，重新启动后恢复 YAML 默认值") {
                        Picker(group.name, selection: proxyBinding(group)) {
                            ForEach(group.candidates, id: \.self) { candidate in
                                Text(candidate).tag(candidate)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 240)
                        .disabled(model.state.mihomoRuntime.selectingProxyGroup != nil)
                    }
                    if group.id != groups.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
    }

    private func proxyBinding(_ group: MihomoProxyGroup) -> Binding<String> {
        Binding(
            get: { group.selected },
            set: { model.selectProxy(group: group.name, proxy: $0) }
        )
    }

    private var proxyActionButton: some View {
        Button(proxyActionTitle, systemImage: proxyActionIcon) {
            model.state.isProxyRunning ? model.stopProxy() : model.startProxy()
        }
        .buttonStyle(.borderedProminent)
        .disabled(proxyActionDisabled)
        .help(model.proxyConfigurationIssue ?? proxyActionTitle)
    }

    private var proxyActionTitle: String {
        switch model.state.proxyCorePhase {
        case .stopped, .failed: model.usesIPv6RequiredTransport ? "启动 IPv6 模式" : "启动代理"
        case .validating, .starting: "正在启动"
        case .running: model.usesIPv6RequiredTransport ? "停止 IPv6 模式" : "停止代理"
        case .stopping: "正在停止"
        }
    }

    private var proxyActionIcon: String {
        model.state.isProxyRunning ? "stop.fill" : "play.fill"
    }

    private var proxyActionDisabled: Bool {
        switch model.state.proxyCorePhase {
        case .validating, .starting, .stopping: true
        case .running: false
        case .stopped, .failed:
            !model.isProxyConfigurationReady || !model.activeProxyRuntimeIsAvailable
                || model.isTemplateOperationBusy || model.switchingIP != nil
        }
    }

    private var headerStatus: String {
        if !model.usesIPv6RequiredTransport { return "兼容模式" }
        return model.state.isProxyRunning ? "IPv6 已启用" : "IPv6 未启用"
    }

    private var headerTone: AppTone {
        if !model.usesIPv6RequiredTransport { return .warning }
        if case .failed = model.state.proxyCorePhase { return .negative }
        return model.state.isProxyRunning ? .positive : .accent
    }

    private var headerIcon: String {
        if !model.usesIPv6RequiredTransport { return "exclamationmark.triangle.fill" }
        return model.state.isProxyRunning ? "checkmark.circle.fill" : "6.circle"
    }

    private var selectedNodeIsIPv6: Bool {
        IPv6Address(
            model.state.preferences.selectedIP.trimmingCharacters(in: .whitespacesAndNewlines)
        ) != nil
    }

    private var selectedNodeDetail: String {
        selectedNodeIsIPv6 ? model.state.preferences.selectedIP : "尚未选择有效 IPv6 地址"
    }

    private var configurationDetail: String {
        model.state.proxySupportsNodeSelection
            ? "主内联节点可注入当前 IPv6 地址"
            : "Provider-only 或当前配置无法保证 IPv6 入口"
    }

    private var tunDetail: String {
        if model.state.tun.isRunning { return "TUN 正在接管公网流量" }
        return model.canUseTunMode ? "服务和固定签名内核已就绪" : "需要安装、批准或修复服务"
    }

    private var publicTrafficDetail: String {
        if model.state.isProxyRunning {
            return model.usesIPv6RequiredTransport
                ? "私有地址直连，其余流量通过 IPv6 代理入口"
                : "流量遵循兼容配置中的路由策略"
        }
        return model.proxyConfigurationIssue ?? "等待启动"
    }

    private var currentNodeResult: SpeedTestResult? {
        if let result = model.state.configurationTest.result,
            result.ip == model.state.preferences.selectedIP
        {
            return result
        }
        return model.state.selectedResult
    }

    private var configurationTestIsRunning: Bool {
        switch model.state.configurationTest.phase {
        case .running, .stopping: true
        case .idle, .failed: false
        }
    }

    private var configurationTestTitle: String {
        configurationTestIsRunning ? "停止测试" : "测试当前节点"
    }

    private var exitModeBinding: Binding<ExitIPDetectionMode> {
        Binding(get: { model.exitIPDetectionMode }, set: { model.exitIPDetectionMode = $0 })
    }
}
