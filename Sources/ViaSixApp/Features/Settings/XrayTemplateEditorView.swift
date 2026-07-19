import SwiftUI
import ViaSixCore

struct XrayTemplateEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var originalText: String?
    @State private var loadError: String?
    @State private var validationError: String?
    @State private var saveError: String?
    @State private var isSaving = false
    @State private var showsDiscardConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("编辑代理配置")
                    .font(.title3.weight(.semibold))
                Text("保存前会检查回环 mixed 入站和 proxy 出站；凭据仍只保存在本机。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .scrollbarSafeContent()
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(VisualStyle.surfaceBorder)
                }
                .disabled(isSaving)
                .accessibilityLabel("Xray JSON 配置")

            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if hasUnsavedChanges {
                    Label("有未保存的更改", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("有未保存的更改")
                }
                Spacer()
                Button("取消", role: .cancel) {
                    requestDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)

                Button {
                    save()
                } label: {
                    HStack(spacing: 6) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(isSaving ? "正在保存…" : "保存配置")
                    }
                    .frame(minWidth: 92)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    isSaving
                        || !hasUnsavedChanges
                        || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 620)
        .task { load() }
        .onChange(of: text) {
            validationError = nil
            saveError = nil
        }
        .interactiveDismissDisabled(isSaving || hasUnsavedChanges)
        .alert("放弃未保存的更改？", isPresented: $showsDiscardConfirmation) {
            Button("继续编辑", role: .cancel) {}
            Button("放弃更改", role: .destructive) { dismiss() }
        } message: {
            Text("关闭后，本次对代理配置的修改将不会保留。")
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let originalText else { return false }
        return text != originalText
    }

    private func load() {
        guard text.isEmpty else { return }
        do {
            text = try String(contentsOf: model.paths.templateConfig, encoding: .utf8)
            originalText = text
        } catch {
            loadError = "读取配置失败：\(error.localizedDescription)"
            originalText = ""
        }
    }

    private func save() {
        validationError = nil
        saveError = nil
        guard let data = text.data(using: .utf8) else {
            validationError = "配置不是有效的 UTF-8 文本"
            return
        }
        do {
            _ = try ConfigTemplate.validateTemplate(data)
        } catch {
            validationError = error.localizedDescription
            return
        }

        isSaving = true
        Task { @MainActor in
            do {
                try await model.saveXrayTemplate(data)
                originalText = text
                isSaving = false
                dismiss()
            } catch is CancellationError {
                isSaving = false
            } catch {
                isSaving = false
                saveError = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    private func requestDismiss() {
        if hasUnsavedChanges {
            showsDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
}
