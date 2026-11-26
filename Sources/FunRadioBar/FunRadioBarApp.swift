import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as a clean Menu Bar utility without Dock clutter
        NSApp.setActivationPolicy(.accessory)
        // Force dark appearance so MenuBarExtra window & native menus always have rich dark contrast
        NSApp.appearance = NSAppearance(named: .darkAqua)

        AppUpdates.shared.start()

        // Initialize the Desktop Widget / Mini-Player controller and show it by default
        _ = MiniPlayerWindowController.shared
        let manager = RadioPlayerManager.shared
        manager.isMiniPlayerVisible = true
        MiniPlayerWindowController.shared.setVisible(true)
    }
}

@main
struct FunRadioBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = RadioPlayerManager.shared

    @ObservedObject private var updates = AppUpdates.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(manager: manager)
                .environment(\.colorScheme, .dark)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: updates.availableVersion != nil ? "arrow.down.circle.fill" : manager.isPlaying ? "dot.radiowaves.left.and.right" : "radio")
                if let labelText = manager.menuBarTitleText {
                    Text(labelText)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
