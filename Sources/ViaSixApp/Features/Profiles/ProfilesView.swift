import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ViaSixCore
import ViaSixMihomoConfig

struct ProfilesView: View {
    @Environment(AppModel.self) private var model
    @State private var summary: MihomoProfileSummary?
    @State private var loadError: String?
    @State private var showsImporter = false
    @State private var showsYAMLEditor = false
    @State private var showsManualEditor = false

    var body: some View {
        VStack(spacing: 0) {
            AppPageHeader("连接配置", subtitle: "管理用于承载当前 IPv6 地址的代理入口") {
                HStack(spacing: VisualStyle.spacing8) {
                    Button("导入", systemImage: "square.and.arrow.down") {
                        showsImporter = true
                    }
                    Button("新建", systemImage: "plus") {
                        showsManualEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .disabled(configurationEditingDisabled)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: VisualStyle.spacing12) {
                    currentProfileCard
                    profileActionsCard
                    safetyCard
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VisualStyle.pageHorizontalPadding)
                .padding(.vertical, VisualStyle.pageVerticalPadding)
            }
            .scrollbarSafeContent()
        }
        .task { await reloadSummary() }
        .onChange(of: model.state.templateOperationPhase) { previous, current in
            guard previous != .idle, current == .idle else { return }
            Task { await reloadSummary() }
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: Self.yamlContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.importProxyProfile(from: url)
            }
        }
        .sheet(isPresented: $showsYAMLEditor) {
            MihomoProfileEditorView().environment(model)
        }
        .sheet(isPresented: $showsManualEditor) {
            ServerConfigurationEditorView().environment(model)
        }
    }

    private var currentProfileCard: some View {
        SurfaceCard {
            CardHeader("当前代理入口", systemImage: "shippingbox", tone: profileTone) {
                StatusBadge(profileStatus, tone: profileTone, systemImage: profileStatusIcon)
            }
            Divider()

            if let summary {
                VStack(alignment: .leading, spacing: VisualStyle.spacing16) {
                    HStack(spacing: VisualStyle.spacing12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(VisualStyle.accent)
                            .frame(width: 46, height: 46)
                            .background(VisualStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(summary.primaryProxyName ?? "ViaSix 代理入口")
                                .font(.title3.weight(.semibold))
                            Text(model.paths.profileConfig.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }

                    Label("当前优选 IPv6 地址将在运行时注入", systemImage: "network")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(VisualStyle.spacing16)
            } else if let loadError {
                ContentUnavailableView {
                    Label("连接配置需要处理", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("导入连接配置", systemImage: "square.and.arrow.down") { showsImporter = true }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ProgressView("正在读取连接配置…")
                    .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
    }

    private var profileActionsCard: some View {
        SurfaceCard {
            CardHeader("连接操作", systemImage: "slider.horizontal.3", tone: .accent)
            Divider()
            VStack(spacing: 0) {
                SettingRow(
                    "可视化编辑",
                    detail: "编辑代理协议、身份凭据、TLS 与传输参数",
                    systemImage: "list.bullet.rectangle"
                ) {
                    Button("编辑", systemImage: "pencil") { showsManualEditor = true }
                }
                Divider().padding(.leading, 52)
                SettingRow("高级 YAML", detail: "编辑代理入口的协议与高级传输字段", systemImage: "curlybraces.square") {
                    Button("打开编辑器", systemImage: "chevron.left.forwardslash.chevron.right") {
                        showsYAMLEditor = true
                    }
                    .disabled(summary == nil)
                }
                Divider().padding(.leading, 52)
                SettingRow("配置文件位置", detail: "在 Finder 中显示私有连接配置", systemImage: "folder") {
                    Button("显示", systemImage: "arrow.up.right.square") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.paths.profileConfig])
                    }
                }
            }
            .padding(.horizontal, VisualStyle.spacing16)
            .padding(.bottom, VisualStyle.spacing12)
            .disabled(configurationEditingDisabled)
        }
    }

    private var safetyCard: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: VisualStyle.spacing12) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(VisualStyle.positive)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("由 ViaSix 管理本机运行字段")
                        .font(.callout.weight(.semibold))
                    Text(
                        "x-viasix 只用于声明由 ViaSix 注入当前优选 IPv6 地址；代理模式、系统代理、TUN、监听端口与其他本机设置不会被 YAML 覆盖。"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(VisualStyle.spacing16)
        }
    }

    private var configurationEditingDisabled: Bool {
        model.state.isProxyRunning || model.isTemplateOperationBusy || model.state.runtimeOperation != nil
    }

    private static let yamlContentTypes = [
        UTType(filenameExtension: "yaml"),
        UTType(filenameExtension: "yml"),
    ].compactMap { $0 }

    private var profileStatus: String {
        if model.isTemplateOperationBusy { return "处理中" }
        if loadError != nil { return "需要配置" }
        return summary == nil ? "读取中" : "已就绪"
    }

    private var profileTone: AppTone {
        if model.isTemplateOperationBusy { return .accent }
        if loadError != nil { return .warning }
        return summary == nil ? .neutral : .positive
    }

    private var profileStatusIcon: String {
        switch profileTone {
        case .positive: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .accent: "arrow.triangle.2.circlepath"
        case .negative: "xmark.circle.fill"
        case .neutral: "clock"
        }
    }

    @MainActor
    private func reloadSummary() async {
        do {
            let data = try await model.loadProfileConfiguration()
            summary = try MihomoServerConfiguration(data: data).summary
            loadError = nil
        } catch {
            summary = nil
            loadError = error.localizedDescription
        }
    }
}
