import AppKit
import SwiftUI

enum VisualStyle {
    static let accent = Color(nsColor: .systemBlue)
    static let surfaceBorder = Color(nsColor: .separatorColor).opacity(0.72)
    static let controlHeight: CGFloat = 34
    static let iconButtonSize: CGFloat = 34
    static let disclosureHitTarget: CGFloat = 44
    static let scrollbarClearance: CGFloat = 14

    static var pageBackground: some View {
        Color(nsColor: .windowBackgroundColor)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VisualStyle.surfaceBorder, lineWidth: 1)
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    /// Shared baseline for the main app surfaces. Typography intentionally follows
    /// the system Dynamic Type setting instead of forcing a single application size.
    func comfortableInterface() -> some View {
        controlSize(.large)
    }

    func iconButtonHitTarget() -> some View {
        self
            .frame(width: VisualStyle.iconButtonSize, height: VisualStyle.iconButtonSize)
            .contentShape(Rectangle())
    }

    func scrollbarSafeContent() -> some View {
        contentMargins(.trailing, VisualStyle.scrollbarClearance, for: .scrollContent)
    }

    func horizontalScrollbarSafeContent() -> some View {
        contentMargins(.bottom, VisualStyle.scrollbarClearance, for: .scrollContent)
    }
}

/// A full-width disclosure control with a predictable hit target and explicit state semantics.
/// SwiftUI's compact disclosure indicator is visually appropriate for macOS, but is easy to
/// miss when it is the only clickable area. This control keeps the familiar indicator while
/// making the entire header interactive.
struct DisclosureControl<Label: View>: View {
    let title: String
    let summary: String?
    @Binding var isExpanded: Bool
    private let label: Label

    init(
        title: String,
        summary: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder label: () -> Label
    ) {
        self.title = title
        self.summary = summary
        _isExpanded = isExpanded
        self.label = label()
    }

    var body: some View {
        let presentation = DisclosurePresentation(
            title: title,
            summary: summary,
            isExpanded: isExpanded
        )

        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                label

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 26, height: 26)
                    .background(.quaternary.opacity(0.72), in: Circle())
                    .accessibilityHidden(true)
            }
            .frame(
                maxWidth: .infinity,
                minHeight: VisualStyle.disclosureHitTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(presentation.helpText)
        .accessibilityLabel(title)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.accessibilityHint)
    }
}

struct DisclosurePresentation: Equatable {
    let title: String
    let summary: String?
    let isExpanded: Bool

    var helpText: String {
        isExpanded ? "收起\(title)" : "展开\(title)"
    }

    var accessibilityValue: String {
        let state = isExpanded ? "已展开" : "已收起"
        guard let summary, !summary.isEmpty else { return state }
        return "\(state)，\(summary)"
    }

    var accessibilityHint: String {
        isExpanded ? "按下可收起" : "按下可展开"
    }
}
