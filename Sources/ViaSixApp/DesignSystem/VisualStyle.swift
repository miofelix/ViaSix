import AppKit
import SwiftUI

enum VisualStyle {
    static let accent = Color(nsColor: .systemBlue)
    static let surfaceBorder = Color(nsColor: .separatorColor).opacity(0.72)
    static let controlHeight: CGFloat = 34
    static let iconButtonSize: CGFloat = 34
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

    /// Shared baseline for the main app surfaces: readable type and comfortable controls.
    func comfortableInterface() -> some View {
        self
            .controlSize(.large)
            .dynamicTypeSize(.xLarge)
    }

    func iconButtonHitTarget() -> some View {
        self
            .frame(width: VisualStyle.iconButtonSize, height: VisualStyle.iconButtonSize)
            .contentShape(Rectangle())
    }

    func scrollbarSafeContent() -> some View {
        contentMargins(.trailing, VisualStyle.scrollbarClearance, for: .scrollContent)
    }
}
