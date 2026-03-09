import AppKit
import SwiftUI
import AirflowBarCore

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private var panel: NSPanel?
    private let panelContent: NSView
    private var eventMonitor: Any?
    private let panelSize = NSSize(width: 380, height: 500)

    var isShown: Bool { panel?.isVisible ?? false }

    init(popoverContent: NSView) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panelContent = popoverContent

        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "wind", accessibilityDescription: "AirflowBar")
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel(_:))
        }
    }

    @objc private func togglePanel(_ sender: AnyObject?) {
        if isShown {
            closePanel()
        } else {
            openPanel()
        }
    }

    func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // Position panel below the status item, right-aligned
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)

        let x = screenRect.midX - panelSize.width / 2
        let y = screenRect.minY - panelSize.height - 4

        let panel = KeyablePanel(
            contentRect: NSRect(origin: NSPoint(x: x, y: y), size: panelSize),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.becomesKeyOnlyIfNeeded = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // Wrap content in a visual effect view for the vibrancy background
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true

        panelContent.frame = visualEffect.bounds
        panelContent.autoresizingMask = [.width, .height]
        visualEffect.addSubview(panelContent)

        panel.contentView = visualEffect

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel

        // Close when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.closePanel()
            }
        }
    }

    func closePanel() {
        panel?.orderOut(nil)
        panel = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func updateBadge(failedCount: Int, runningCount: Int, isDisconnected: Bool) {
        guard let button = statusItem.button else { return }

        button.appearsDisabled = false

        if isDisconnected {
            button.image = makeIcon(color: nil)
            button.appearsDisabled = true
            button.attributedTitle = NSAttributedString()
        } else if failedCount > 0 {
            button.image = makeIcon(color: .systemRed)
            button.attributedTitle = makeBadgeTitle("\(failedCount)", color: .systemRed)
        } else if runningCount > 0 {
            button.image = makeIcon(color: nil)
            button.attributedTitle = makeBadgeTitle("\(runningCount)", color: .secondaryLabelColor)
        } else {
            button.image = makeIcon(color: nil)
            button.attributedTitle = NSAttributedString()
        }
    }

    // MARK: - Helpers

    private func makeIcon(color: NSColor?) -> NSImage? {
        guard let symbol = NSImage(
            systemSymbolName: "wind",
            accessibilityDescription: "AirflowBar"
        ) else { return nil }

        if let color {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                .applying(.init(paletteColors: [color]))
            let colored = symbol.withSymbolConfiguration(config)
            colored?.isTemplate = false
            return colored
        }

        symbol.isTemplate = true
        return symbol
    }

    private func makeBadgeTitle(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: " \(text)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: color,
            ]
        )
    }
}
