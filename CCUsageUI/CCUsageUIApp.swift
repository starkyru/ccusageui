import SwiftUI

@main
struct CCUsageUIApp: App {
    @StateObject private var usageService = UsageService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(usageService)
        } label: {
            Image(systemName: "chart.bar.fill")
                .symbolRenderingMode(.monochrome)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(usageService)
        }
    }
}
