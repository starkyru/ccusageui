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
            let pct = Int(usageService.percentage)
            let color = usageService.usageColor.color
            let img = NSImage(systemSymbolName: "square.fill", accessibilityDescription: "usage")!
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            let colored = img.withSymbolConfiguration(config)!

            HStack(spacing: 4) {
                Image(nsImage: tinted(image: colored, color: color))
                Text("\(pct)%")
                    .monospacedDigit()
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(usageService)
        }
    }

    private func tinted(image: NSImage, color: NSColor) -> NSImage {
        let tinted = image.copy() as! NSImage
        tinted.lockFocus()
        color.set()
        let rect = NSRect(origin: .zero, size: tinted.size)
        rect.fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}
