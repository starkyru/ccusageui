import SwiftUI

struct MenuBarPopover: View {
    @EnvironmentObject var usageService: UsageService
    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 12) {
            headerView

            HStack(spacing: 16) {
                usageBar
                statsView
            }
            .frame(height: 180)

            if showingDetail {
                detailView
            }

            footerView
        }
        .padding(16)
        .frame(width: 320)
    }

    private var headerView: some View {
        HStack {
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var usageBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .separatorColor))

                // Filled portion
                RoundedRectangle(cornerRadius: 8)
                    .fill(barColor)
                    .frame(height: geometry.size.height * fillAmount)

                // Threshold markers
                ForEach(thresholdMarkers, id: \.0) { marker in
                    Rectangle()
                        .fill(Color(nsColor: .tertiaryLabelColor))
                        .frame(height: 1)
                        .offset(y: -geometry.size.height * CGFloat(marker.1 / 100) + geometry.size.height / 2)
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingDetail.toggle()
                }
            }
        }
        .frame(width: 48)
        .help("Click to show details")
    }

    private var statsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Cost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "$%.2f", usageService.currentCost))
                    .font(.title2.monospacedDigit())
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "$%.0f", usageService.dailyBudget))
                    .font(.body.monospacedDigit())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f%%", usageService.percentage))
                    .font(.title3.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(barSwiftUIColor)
            }

            Spacer()
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
            .frame(height: 160)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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

    private var barSwiftUIColor: Color {
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
