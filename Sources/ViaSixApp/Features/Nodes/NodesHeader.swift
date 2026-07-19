import SwiftUI

extension NodesView {
    // MARK: - Header

    var pageHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 20) {
                pageTitle
                Spacer(minLength: 16)
                currentNodeSummary
            }

            VStack(alignment: .leading, spacing: 12) {
                pageTitle
                compactCurrentNodeSummary
            }
        }
        .padding(.vertical, 2)
    }

    private var pageTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("节点测速")
                .font(.title2.weight(.semibold))
            Text("比较候选节点，确认后应用到本地代理")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var currentNodeSummary: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("当前节点")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currentIPLabel)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .multilineTextAlignment(.trailing)
        }
    }

    private var compactCurrentNodeSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("当前节点")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currentIPLabel)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
