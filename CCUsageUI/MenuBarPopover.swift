import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var usageService: UsageService

    var body: some View {
        VStack(spacing: 12) {
            headerView

            HStack(alignment: .top, spacing: 0) {
                // Left panel: two bar columns side by side
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 12) {
                        barColumn(
                            label: "Session",
                            used: usageService.sessionTokensUsed,
                            limit: usageService.sessionTokenLimit,
                            percentage: usageService.sessionPercentage,
                            color: usageService.sessionColor
                        )
                        barColumn(
                            label: "Week",
                            used: usageService.weeklyTokensUsed,
                            limit: usageService.weeklyTokenLimit,
                            percentage: usageService.weeklyPercentage,
                            color: usageService.weeklyColor
                        )
                    }

                    if usageService.sessionRemainingMinutes > 0 {
                        let hours = usageService.sessionRemainingMinutes / 60
                        let minutes = usageService.sessionRemainingMinutes % 60
                        Text("Resets in \(hours)h \(minutes)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 180)

                Divider()
                    .padding(.horizontal, 12)

                // Right panel: ccusage text output
                detailView
            }
            .frame(height: 380)

            footerView
        }
        .padding(16)
        .frame(width: 920)
    }

    // MARK: - Components

    private var headerView: some View {
        HStack {
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            SettingsLink {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func barColumn(label: String, used: Int, limit: Int, percentage: Double, color: UsageLevel) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .separatorColor))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: color.color))
                        .frame(height: geometry.size.height * CGFloat(min(percentage, 100) / 100))

                    ForEach(thresholdMarkers, id: \.0) { marker in
                        Rectangle()
                            .fill(Color(nsColor: .tertiaryLabelColor))
                            .frame(height: 1)
                            .offset(y: -geometry.size.height * CGFloat(marker.1 / 100) + geometry.size.height / 2)
                    }
                }
            }
            .frame(width: 36)

            VStack(spacing: 4) {
                Text(String(format: "%.1f%%", percentage))
                    .font(.caption.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(Color(nsColor: color.color))

                Text("\(UsageService.formatTokens(used)) / \(UsageService.formatTokens(limit))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ccusage output")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(usageService.rawOutput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var footerView: some View {
        HStack {
            if let lastUpdated = usageService.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                usageService.fetchUsage()
            } label: {
                if usageService.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    // MARK: - Helpers

    private var thresholdMarkers: [(String, Double)] {
        [
            ("green", usageService.greenThreshold),
            ("yellow", usageService.yellowThreshold),
            ("red", usageService.redThreshold),
        ]
    }
}
