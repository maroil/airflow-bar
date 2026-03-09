import AppKit
import SwiftUI
import AirflowBarCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItemController: StatusItemController!
    private var viewModel: DAGStatusViewModel!
    private var configStore: ConfigStore!
    private var updateViewModel: UpdateCheckViewModel!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Set up notifications — register bundle ID for swift run, request authorization
        setupNotifications()

        configStore = ConfigStore()
        viewModel = DAGStatusViewModel(configStore: configStore)
        updateViewModel = UpdateCheckViewModel(configStore: configStore)

        let popoverView = PopoverContent(
            viewModel: viewModel,
            configStore: configStore,
            updateViewModel: updateViewModel,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onRefresh: { [weak self] in
                Task { @MainActor in await self?.viewModel.refresh() }
            }
        )

        let hostingView = NSHostingView(rootView: popoverView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 500)

        statusItemController = StatusItemController(popoverContent: hostingView)

        // Badge updates via closure instead of polling timer
        viewModel.onBadgeUpdate = { [weak self] failedCount, runningCount, isDisconnected in
            self?.statusItemController.updateBadge(
                failedCount: failedCount,
                runningCount: runningCount,
                isDisconnected: isDisconnected
            )
        }

        // Screenshot mode: populate with mock data and skip polling
        if ScreenshotMode.isEnabled {
            ScreenshotMode.configure(viewModel: viewModel, configStore: configStore)
            statusItemController.updateBadge(
                failedCount: viewModel.failedCount,
                runningCount: viewModel.runningCount,
                isDisconnected: false
            )
            // Auto-open the panel for easy screenshotting
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                self?.statusItemController.openPanel()
            }
            return
        }

        // Start polling
        viewModel.startPolling()

        // Check for app updates
        updateViewModel.checkIfNeeded()

        // Auto-open settings on first launch if no environment configured
        if !configStore.hasEnvironments {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.openSettings()
            }
        }
    }

    func openSettings() {
        // Close the panel so it doesn't cover the settings window
        statusItemController.closePanel()

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let settingsView = SettingsView(configStore: configStore, updateViewModel: updateViewModel, onSave: { [weak self] in
            guard let self else { return }
            self.viewModel.stopPolling()
            self.viewModel.startPolling()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AirflowBar Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        settingsWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopPolling()
    }

    // MARK: - Notifications

    private func setupNotifications() {
        // UNUserNotificationCenter requires a bundle identifier.
        // When running as .app bundle this works; for `swift run` it's nil.
        guard Bundle.main.bundleIdentifier != nil else { return }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    // Show notifications even when the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
