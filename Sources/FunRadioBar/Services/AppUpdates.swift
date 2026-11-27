import Sparkle
import SwiftUI

@MainActor
final class AppUpdates: NSObject, ObservableObject, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = AppUpdates()
    static let installedVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Dev"

    @Published private(set) var canCheck = false
    @Published private(set) var checksAutomatically = false
    @Published private(set) var availableVersion: String?
    private var controller: SPUStandardUpdaterController?

    func start() {
        guard Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheck)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$checksAutomatically)
        controller.startUpdater()
    }

    func check() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        if !handleShowingUpdate { availableVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
