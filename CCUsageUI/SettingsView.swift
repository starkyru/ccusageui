import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var usageService: UsageService
    @AppStorage("dailyBudget") private var dailyBudget: Double = 100.0
    @AppStorage("greenThreshold") private var greenThreshold: Double = 50
    @AppStorage("yellowThreshold") private var yellowThreshold: Double = 70
    @AppStorage("redThreshold") private var redThreshold: Double = 90
    @AppStorage("refreshInterval") private var refreshInterval: Double = 5

    var body: some View {
        Form {
            Section("Budget") {
                HStack {
                    Text("Daily Budget ($)")
                    Spacer()
                    TextField("Budget", value: $dailyBudget, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Color Thresholds (%)") {
                thresholdRow(label: "Green → Yellow", color: .green, value: $greenThreshold)
                thresholdRow(label: "Yellow → Red", color: .yellow, value: $yellowThreshold)
                thresholdRow(label: "Red → Black", color: .red, value: $redThreshold)

                thresholdPreview
            }

            Section("Refresh") {
                HStack {
                    Text("Interval (minutes)")
                    Spacer()
                    TextField("Minutes", value: $refreshInterval, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack {
                Spacer()
                Button("Apply") {
                    usageService.dailyBudget = dailyBudget
                    usageService.greenThreshold = greenThreshold
                    usageService.yellowThreshold = yellowThreshold
                    usageService.redThreshold = redThreshold
                    usageService.refreshInterval = refreshInterval
                    usageService.restartTimer()
                    usageService.fetchUsage()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 400)
    }

    private func thresholdRow(label: String, color: Color, value: Binding<Double>) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
            Spacer()
            TextField("%", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
            Text("%")
                .foregroundStyle(.secondary)
        }
    }

    private var thresholdPreview: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                let width = geometry.size.width
                Rectangle()
                    .fill(.green)
                    .frame(width: width * greenThreshold / 100)
                Rectangle()
                    .fill(.yellow)
                    .frame(width: width * (yellowThreshold - greenThreshold) / 100)
                    .offset(x: width * greenThreshold / 100)
                Rectangle()
                    .fill(.red)
                    .frame(width: width * (redThreshold - yellowThreshold) / 100)
                    .offset(x: width * yellowThreshold / 100)
                Rectangle()
                    .fill(.black)
                    .frame(width: width * (100 - redThreshold) / 100)
                    .offset(x: width * redThreshold / 100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 20)
    }
}
