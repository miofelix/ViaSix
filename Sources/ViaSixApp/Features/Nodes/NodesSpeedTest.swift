import SwiftUI

extension NodesView {
    // MARK: - Test and Results

    var speedTestCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            speedTestHeader

            if isTesting {
                Group {
                    if model.state.speedTest.total == 0 {
                        ProgressView()
                            .progressViewStyle(.linear)
                    } else {
                        ProgressView(value: model.state.speedTest.fractionCompleted)
                            .progressViewStyle(.linear)
                            .tint(VisualStyle.accent)
                    }
                }
                .accessibilityLabel("测速进度")
                .accessibilityValue(progressAccessibilityValue)

                progressSummary
            } else if isCfstBusyElsewhere {
                Label("完成当前节点测速后，即可开始新的候选节点扫描。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                idleSummary
            }

            if let parameterValidationMessage {
                Label(parameterValidationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if speedTestReadinessMessage != nil {
                readinessSummary
            }
        }
        .padding(20)
        .cardStyle()
    }

    private var speedTestHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                speedTestTitle
                Spacer(minLength: 12)
                speedTestAction
            }

            VStack(alignment: .leading, spacing: 10) {
                speedTestTitle
                HStack {
                    Spacer(minLength: 0)
                    speedTestAction
                }
            }
        }
    }

    private var speedTestTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("IP 测速")
                .font(.headline)
            Text(speedTestStatusText)
                .font(.caption)
                .foregroundStyle(speedTestStatusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var speedTestAction: some View {
        Group {
            if isTesting {
                Button(role: .destructive) {
                    model.stopSpeedTest()
                } label: {
                    Label(isStopping ? "正在停止" : "停止", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStopping)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showsParameters = false
                    }
                    model.startSpeedTest()
                } label: {
                    Label("开始测速", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(VisualStyle.accent)
                .disabled(!canStartSpeedTest)
            }
        }
    }

    private var progressSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                Text(progressLabel)
                Text(progressPercentage)
                Spacer(minLength: 0)
                Text(receivedOutputLabel)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 16) {
                    Text(progressLabel)
                    Text(progressPercentage)
                }
                Text(receivedOutputLabel)
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    private var idleSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                idleSummarySource
                Divider()
                    .frame(height: 14)
                idleSummaryParameters
                Spacer(minLength: 0)
                idleSummaryCount
            }

            VStack(alignment: .leading, spacing: 5) {
                idleSummarySource
                idleSummaryParameters
                idleSummaryCount
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var idleSummarySource: some View {
        Label(sourceSummary, systemImage: "list.bullet.rectangle")
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var idleSummaryParameters: some View {
        Text(parameterSummary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var idleSummaryCount: some View {
        if !model.state.results.isEmpty {
            Text("\(model.state.results.count) 个结果")
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var readinessSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                readinessLabel
                Spacer(minLength: 8)
                settingsLink
            }

            VStack(alignment: .leading, spacing: 6) {
                readinessLabel
                settingsLink
            }
        }
    }

    private var readinessLabel: some View {
        Label(speedTestReadinessMessage ?? "", systemImage: "shippingbox")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var settingsLink: some View {
        SettingsLink {
            Text("打开设置")
        }
        .font(.caption.weight(.medium))
    }
}
