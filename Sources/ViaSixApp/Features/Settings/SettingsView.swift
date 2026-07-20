import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViaSixCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showsCustomExecutables = false
    @State private var showsTemplateEditor = false
    @State private var showsLocalProxyEditor = false
    @State private var presentedServerEditorMode: ServerConfigurationInputMode?
    @State private var exitIPEndpointDraft = ""
    @State private var exitIPEndpointError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VisualStyle.spacing20) {
                AppPageHeader("设置", subtitle: "连接、网络接入与运行组件")

                serverConfigurationCard
                localProxyCard
                runtimeCard
                dataCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollbarSafeContent()
        .onAppear {
            if exitIPEndpointDraft.isEmpty {
                exitIPEndpointDraft = model.exitIPEndpoint
            }
        }
        .onChange(of: model.exitIPEndpoint) { _, endpoint in
            if endpoint != exitIPEndpointDraft {
                exitIPEndpointDraft = endpoint
                exitIPEndpointError = nil
            }
        }
    }

    private var runtimeCard: some View {
        SurfaceCard {
            CardHeader("运行组件", systemImage: "shippingbox") {
                runtimeBadge
            }
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                componentRow(
                    component: .cfst,
                    url: resolvedDisplayURL(for: .cfst),
                    ready: componentReady(.cfst)
                )
                Divider()
                    .padding(.leading, 52)
                componentRow(
                    component: .xray,
                    url: resolvedDisplayURL(for: .xray),
                    ready: componentReady(.xray)
                )

                Divider()

                HStack(spacing: VisualStyle.spacing8) {
                    Button(runtimeInstallTitle, systemImage: "arrow.down.circle") {
                        model.installRuntime()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeActionsDisabled)

                    Button("导入组件", systemImage: "square.and.arrow.down") {
                        importRuntime()
                    }
                    .disabled(runtimeActionsDisabled)

                    Spacer()

                    if model.state.runtimeOperation?.canCancel == true {
                        Button("取消", systemImage: "xmark.circle") {
                            model.cancelRuntimeOperation()
                        }
                    }
                }
                .padding(.vertical, VisualStyle.spacing12)

                runtimeOperationStatus

                if let issue = model.runtimeIntegrityIssue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, VisualStyle.spacing12)
                }

                if let message = model.state.runtimeOperationError {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, VisualStyle.spacing12)
                }

                Divider()

                DisclosureControl(
                    title: "自定义可执行文件",
                    summary: "指定开发版或自行构建的组件",
                    isExpanded: $showsCustomExecutables
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自定义可执行文件")
                            .font(.subheadline.weight(.medium))
                        Text("指定开发版或自行构建的组件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsCustomExecutables {
                    VStack(alignment: .leading, spacing: 14) {
                        executablePicker(
                            title: "CFST 路径",
                            value: model.state.preferences.cfstPath,
                            component: .cfst
                        )
                        executablePicker(
                            title: "Xray 路径",
                            value: model.state.preferences.xrayPath,
                            component: .xray
                        )

                        Text("留空时使用 ViaSix 管理的组件，也会检查 Homebrew 与 PATH。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
    }

    @ViewBuilder
    private var runtimeOperationStatus: some View {
        if let operation = model.state.runtimeOperation {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(operation.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(operation.description)
        }
    }

    private var serverConfigurationCard: some View {
        SurfaceCard {
            CardHeader("服务器连接", systemImage: "server.rack", tone: serverStatusTone) {
                StatusBadge(
                    serverStatusTitle,
                    tone: serverStatusTone,
                    systemImage: serverStatusSystemImage
                )
            }
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                SettingRow(
                    "连接方式",
                    detail: "VLESS、VMess、Trojan、Shadowsocks",
                    systemImage: "point.3.connected.trianglepath.dotted"
                ) {
                    HStack(spacing: VisualStyle.spacing8) {
                        Button("分享链接", systemImage: "link") {
                            presentedServerEditorMode = .shareLink
                        }
                        .disabled(serverEditorDisabled)

                        Button("手动配置", systemImage: "slider.horizontal.3") {
                            presentedServerEditorMode = .manual
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(serverEditorDisabled)
                    }
                }

                Divider()
                    .padding(.leading, 52)

                SettingRow(
                    "高级配置",
                    detail: "直接编辑或导入 Xray JSON",
                    systemImage: "curlybraces.square"
                ) {
                    Menu {
                        Button("编辑服务器 JSON", systemImage: "curlybraces.square") {
                            showsTemplateEditor = true
                        }
                        .disabled(!serverConfigurationExists)

                        Button("导入完整 Xray JSON…", systemImage: "square.and.arrow.down") {
                            importXrayTemplate()
                        }
                    } label: {
                        Label("高级", systemImage: "ellipsis.circle")
                    }
                    .disabled(proxyImportDisabled)
                }

                proxyConfigurationFeedback
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
        .sheet(isPresented: $showsTemplateEditor) {
            XrayTemplateEditorView()
                .environment(model)
        }
        .sheet(item: $presentedServerEditorMode) { mode in
            ServerConfigurationEditorView(initialInputMode: mode)
                .environment(model)
        }
    }

    private var localProxyCard: some View {
        SurfaceCard {
            CardHeader("本机代理", systemImage: "laptopcomputer", tone: .accent) {
                Button("编辑", systemImage: "slider.horizontal.3") {
                    showsLocalProxyEditor = true
                }
                .disabled(proxyImportDisabled)
            }
            Divider()

            VStack(spacing: 0) {
                SettingRow(
                    "代理模式",
                    detail: model.state.localProxyConfiguration.routingMode.appDescription,
                    systemImage: model.state.localProxyConfiguration.routingMode.appSystemImage
                ) {
                    StatusBadge(
                        model.state.localProxyConfiguration.routingMode.displayName,
                        tone: .accent
                    )
                }

                Divider()
                    .padding(.leading, 52)

                SettingRow(
                    "系统代理",
                    detail: systemProxyConfigurationDetail,
                    systemImage: "network"
                ) {
                    StatusBadge(
                        systemProxyPresentation.text,
                        tone: systemProxyPresentation.appTone,
                        systemImage: systemProxyStatusSystemImage
                    )
                }

                Divider()
                    .padding(.leading, 52)

                SettingRow(
                    "监听端点",
                    detail: "HTTP 与 SOCKS 共用本地 mixed 入口",
                    systemImage: "dot.radiowaves.left.and.right"
                ) {
                    Text(model.state.proxyEndpoint.displayAddress)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
        .sheet(isPresented: $showsLocalProxyEditor) {
            LocalProxySettingsView()
                .environment(model)
        }
    }

    private var dataCard: some View {
        SurfaceCard {
            CardHeader("应用与数据", systemImage: "folder", tone: .neutral)
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                SettingRow(
                    "数据目录",
                    detail: model.paths.root.path,
                    systemImage: "folder"
                ) {
                    Button("打开", systemImage: "arrow.up.right.square") {
                        NSWorkspace.shared.open(model.paths.root)
                    }
                }

                Divider()
                    .padding(.leading, 52)

                SettingRow(
                    "出口 IP 检测服务",
                    detail: exitIPEndpointError ?? "自动检测出口地址时使用",
                    systemImage: "location"
                ) {
                    HStack(spacing: VisualStyle.spacing8) {
                        TextField(
                            AppMetadata.defaultExitIPEndpoint,
                            text: $exitIPEndpointDraft
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 220, idealWidth: 320, maxWidth: 380)
                        .accessibilityLabel("出口 IP 检测服务地址")
                        .accessibilityHint("使用 HTTP 或 HTTPS 地址")
                        .onChange(of: exitIPEndpointDraft) { _, value in
                            validateAndSaveExitIPEndpoint(value)
                        }

                        Button {
                            exitIPEndpointDraft = AppMetadata.defaultExitIPEndpoint
                            validateAndSaveExitIPEndpoint(exitIPEndpointDraft)
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .buttonStyle(.borderless)
                        .iconButtonHitTarget()
                        .help("恢复默认检测服务")
                        .accessibilityLabel("恢复默认检测服务")
                        .disabled(exitIPEndpointDraft == AppMetadata.defaultExitIPEndpoint)
                    }
                }

                Divider()

                HStack(spacing: VisualStyle.spacing8) {
                    Button("使用帮助", systemImage: "questionmark.circle") {
                        AppDocumentOpener.open(.userGuide)
                    }
                    Button("第三方许可", systemImage: "doc.plaintext") {
                        AppDocumentOpener.open(.thirdPartyNotices)
                    }
                    Spacer()
                }
                .padding(.vertical, VisualStyle.spacing12)
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
        }
    }

    @ViewBuilder
    private var proxyConfigurationFeedback: some View {
        if let templateOperationStatus {
            Divider()
            HStack(spacing: VisualStyle.spacing8) {
                ProgressView()
                    .controlSize(.small)
                Text(templateOperationStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, VisualStyle.spacing12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(templateOperationStatus)
        } else if let error = model.state.templateOperationError {
            Divider()
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, VisualStyle.spacing12)
        } else if let issue = model.proxyConfigurationIssue {
            Divider()
            Label(issue, systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, VisualStyle.spacing12)
        } else if proxyImportDisabled {
            Divider()
            Text(proxyImportBlockedMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, VisualStyle.spacing12)
        }
    }

    private var serverConfigurationExists: Bool {
        FileManager.default.fileExists(atPath: model.paths.serverConfig.path)
    }

    private var serverEditorDisabled: Bool {
        proxyImportDisabled
    }

    private var serverStatusTitle: String {
        if model.state.templateOperationPhase != .idle { return "处理中" }
        if model.state.templateOperationError != nil { return "操作失败" }
        if !serverConfigurationExists { return "未配置" }
        if model.proxyConfigurationIssue != nil { return "需要检查" }
        return "可用"
    }

    private var serverStatusTone: AppTone {
        if model.state.templateOperationPhase != .idle { return .accent }
        if model.state.templateOperationError != nil { return .negative }
        if !serverConfigurationExists || model.proxyConfigurationIssue != nil { return .warning }
        return .positive
    }

    private var serverStatusSystemImage: String {
        switch serverStatusTone {
        case .accent: "arrow.triangle.2.circlepath"
        case .positive: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .negative: "xmark.circle.fill"
        case .neutral: "circle"
        }
    }

    private var systemProxyConfigurationDetail: String {
        model.state.localProxyConfiguration.systemProxyEnabled
            ? "启动本地代理后接入 macOS 系统代理"
            : "启动本地代理时不修改 macOS 系统代理"
    }

    private var systemProxyPresentation: SystemProxyStatusPresentation {
        SystemProxyStatusPresentation(
            phase: model.state.systemProxyPhase,
            isRequested: model.state.localProxyConfiguration.systemProxyEnabled
        )
    }

    private var systemProxyStatusSystemImage: String {
        if systemProxyPresentation.isTransitioning {
            return "hourglass"
        }
        return switch systemProxyPresentation.tone {
        case .active: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .pending: "clock.fill"
        case .neutral: "circle"
        }
    }

    private var runtimeBadge: some View {
        let (label, tone, systemImage): (String, AppTone, String) =
            if model.state.runtimeOperation != nil {
                ("操作中", .accent, "arrow.triangle.2.circlepath")
            } else if model.state.runtimeOperationError != nil {
                ("操作失败", .negative, "xmark.circle.fill")
            } else if model.runtimeIntegrityIssue != nil {
                ("需修复", .warning, "exclamationmark.circle.fill")
            } else {
                switch model.state.runtimePhase {
                case .checking: ("检查中", .neutral, "arrow.triangle.2.circlepath")
                case .missing: ("未就绪", .warning, "exclamationmark.circle.fill")
                case .ready: ("已就绪", .positive, "checkmark.circle.fill")
                }
            }
        return StatusBadge(label, tone: tone, systemImage: systemImage)
    }

    private var runtimeInstallTitle: String {
        if model.state.runtimeOperationError != nil {
            return model.hasCfstExecutable && model.hasXrayExecutable
                ? "重试更新"
                : "重试安装"
        }
        return model.hasCfstExecutable && model.hasXrayExecutable
            ? "重新安装组件"
            : "安装组件"
    }

    private func componentRow(
        component: RuntimeComponent,
        url: URL?,
        ready: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ready ? .green : .orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Link(destination: component.repositoryURL) {
                    HStack(spacing: 6) {
                        Text(component.displayName)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("在 GitHub 打开 \(component.displayName)")
                Text(url?.path ?? "未找到")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .frame(minHeight: VisualStyle.settingsRowHeight)
    }

    private func executablePicker(
        title: String,
        value: String,
        component: RuntimeComponent
    ) -> some View {
        let editingDisabled = componentPathEditingDisabled(component)
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
            HStack {
                TextField(
                    "自动查找",
                    text: Binding(
                        get: { value },
                        set: { newValue in
                            model.setCustomExecutable(
                                component,
                                url: newValue.isEmpty ? nil : URL(fileURLWithPath: newValue)
                            )
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
                .disabled(editingDisabled)

                Button("选择…") {
                    chooseExecutable(component)
                }
                .disabled(editingDisabled)
                Button {
                    model.setCustomExecutable(component, url: nil)
                } label: {
                    Image(systemName: "xmark")
                }
                .iconButtonHitTarget()
                .help("清除自定义路径")
                .accessibilityLabel("清除\(title)")
                .disabled(value.isEmpty || editingDisabled)
            }
            if editingDisabled {
                Text(componentPathEditingMessage(component))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func componentReady(_ component: RuntimeComponent) -> Bool {
        resolvedDisplayURL(for: component) != nil
    }

    private func componentPathEditingDisabled(_ component: RuntimeComponent) -> Bool {
        if model.state.runtimeOperation != nil { return true }
        return switch component {
        case .cfst:
            model.isCfstBusy
        case .xray:
            switch model.state.xrayPhase {
            case .validating, .starting, .running, .stopping:
                true
            case .stopped, .failed:
                false
            }
        }
    }

    private func componentPathEditingMessage(_ component: RuntimeComponent) -> String {
        if let operation = model.state.runtimeOperation {
            return "\(operation.description)，完成后才能修改路径。"
        }
        return switch component {
        case .cfst: "测速进行中，停止后才能修改路径。"
        case .xray: "本地代理运行中，停止后才能修改路径。"
        }
    }

    private func resolvedDisplayURL(for component: RuntimeComponent) -> URL? {
        let (preferredPath, managedURL, commandName): (String, URL?, String) =
            switch component {
            case .cfst:
                (model.state.preferences.cfstPath, model.state.runtimeStatus?.cfstURL, "cfst")
            case .xray:
                (
                    model.state.preferences.xrayPath,
                    model.state.runtimeStatus?.xrayIsReady == true
                        ? model.state.runtimeStatus?.xrayURL
                        : nil,
                    "xray"
                )
            }

        var candidates: [URL] = []
        if !preferredPath.isEmpty {
            candidates.append(URL(fileURLWithPath: preferredPath))
        }
        if let managedURL {
            candidates.append(managedURL)
        }
        candidates.append(URL(fileURLWithPath: "/opt/homebrew/bin/\(commandName)"))
        candidates.append(URL(fileURLWithPath: "/usr/local/bin/\(commandName)"))
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates.append(
                contentsOf: path.split(separator: ":").map {
                    URL(fileURLWithPath: String($0)).appendingPathComponent(commandName)
                })
        }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private var runtimeActionsDisabled: Bool {
        guard model.state.launchPhase == .ready else { return true }
        if model.state.runtimeOperation != nil
            || model.isTemplateOperationBusy
            || model.switchingIP != nil
        {
            return true
        }
        if model.isCfstBusy { return true }

        switch model.state.speedTest.phase {
        case .running, .stopping:
            return true
        case .idle, .failed:
            break
        }

        switch model.state.xrayPhase {
        case .validating, .starting, .running, .stopping:
            return true
        case .stopped, .failed:
            return false
        }
    }

    private var proxyImportDisabled: Bool {
        guard model.state.launchPhase == .ready else { return true }
        guard model.state.templateOperationPhase == .idle else { return true }
        guard model.switchingIP == nil else { return true }
        guard model.state.runtimeOperation == nil else { return true }
        return switch model.state.xrayPhase {
        case .validating, .starting, .running, .stopping:
            true
        case .stopped, .failed:
            false
        }
    }

    private var proxyImportBlockedMessage: String {
        switch model.state.launchPhase {
        case .idle, .loading:
            return "正在加载应用数据，完成后即可导入或编辑连接配置。"
        case .failed(let message):
            return "应用初始化失败：\(message)"
        case .ready:
            break
        }
        if let operation = model.state.runtimeOperation {
            return "\(operation.description)，完成后再导入或编辑连接配置。"
        }
        if model.switchingIP != nil {
            return "正在应用节点，完成后再导入或编辑连接配置。"
        }
        return "请先停止本地代理，再导入或编辑连接配置。"
    }

    private var templateOperationStatus: String? {
        switch model.state.templateOperationPhase {
        case .idle:
            nil
        case .importing:
            "正在导入代理配置，请稍候…"
        case .saving:
            "正在保存代理配置，请稍候…"
        }
    }

    private func chooseExecutable(_ component: RuntimeComponent) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            model.setCustomExecutable(component, url: panel.url)
        }
    }

    private func validateAndSaveExitIPEndpoint(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            exitIPEndpointError = "检测服务地址不能为空；可点击右侧按钮恢复默认地址。"
            return
        }
        guard
            let url = URL(string: normalized),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else {
            exitIPEndpointError = "请输入有效的 HTTP 或 HTTPS 地址。"
            return
        }
        exitIPEndpointError = nil
        model.exitIPEndpoint = normalized
    }

    private func importRuntime() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            model.importRuntime(from: panel.urls)
        }
    }

    private func importXrayTemplate() {
        let panel = NSOpenPanel()
        panel.title = "导入代理配置"
        panel.message = "选择包含“proxy”出站连接的 Xray JSON 配置。"
        panel.prompt = "导入"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            model.importXrayTemplate(from: url)
        }
    }
}
