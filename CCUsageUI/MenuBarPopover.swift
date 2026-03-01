import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var usageService: UsageService

    var body: some View {
        VStack(spacing: 12) {
            headerView

            HStack(alignment: .top, spacing: 0) {
                // Left column: bar chart + stats
                VStack(spacing: 12) {
                    usageBar
                    statsView
                }
                .frame(width: 100)

                Divider()
                    .padding(.horizontal, 12)

                // Right column: ccusage output
                detailView
            }
            .frame(height: 380)

            footerView
        }
        .padding(16)
        .frame(width: 920)
    }

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

    private var usageBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .separatorColor))

                RoundedRectangle(cornerRadius: 8)
                    .fill(barColor)
                    .frame(height: geometry.size.height * fillAmount)

                ForEach(thresholdMarkers, id: \.0) { marker in
                    Rectangle()
                        .fill(Color(nsColor: .tertiaryLabelColor))
                        .frame(height: 1)
                        .offset(y: -geometry.size.height * CGFloat(marker.1 / 100) + geometry.size.height / 2)
                }
            }
        }
        .frame(width: 36)
    }

    private var statsView: some View {
        VStack(alignment: .center, spacing: 8) {
            let cost = String(format: "$%.2f", usageService.currentCost)
            let budget = String(format: "$%.0f", usageService.dailyBudget)
            let pct = String(format: "%.1f", usageService.percentage)

            Text("\(pct)%")
                .font(.title2.monospacedDigit())
                .fontWeight(.bold)
                .foregroundStyle(barColor)

            VStack(spacing: 2) {
                Text(cost)
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
                Text("of \(budget)")
                    .font(.caption2)
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

    private var fillAmount: CGFloat {
        CGFloat(min(usageService.percentage, 100) / 100)
    }

    private var barColor: Color {
        Color(nsColor: usageService.usageColor.color)
    }

    private var thresholdMarkers: [(String, Double)] {
        [
            ("green", usageService.greenThreshold),
            ("yellow", usageService.yellowThreshold),
            ("red", usageService.redThreshold),
        ]
    }
}
