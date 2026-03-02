import SwiftUI
import AppKit

@main
struct CCUsageUIApp: App {
    @StateObject private var usageService = UsageService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(usageService)
        } label: {
            Image(nsImage: dualBarIcon(
                leftColor: usageService.sessionColor.color,
                rightColor: usageService.weeklyColor.color
            ))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(usageService)
        }
    }

    private func dualBarIcon(leftColor: NSColor, rightColor: NSColor) -> NSImage {
        let barWidth: CGFloat = 5
        let barHeight: CGFloat = 14
        let gap: CGFloat = 2
        let totalWidth = barWidth * 2 + gap
        let size = NSSize(width: totalWidth, height: barHeight)

        let image = NSImage(size: size, flipped: false) { _ in
            let leftRect = NSRect(x: 0, y: 0, width: barWidth, height: barHeight)
            let leftPath = NSBezierPath(roundedRect: leftRect, xRadius: 2, yRadius: 2)
            leftColor.setFill()
            leftPath.fill()

            let rightRect = NSRect(x: barWidth + gap, y: 0, width: barWidth, height: barHeight)
            let rightPath = NSBezierPath(roundedRect: rightRect, xRadius: 2, yRadius: 2)
            rightColor.setFill()
            rightPath.fill()

            return true
        }
        image.isTemplate = false
        return image
    }
}
