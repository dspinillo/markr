import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var iconResetWorkItem: DispatchWorkItem?
    private var permissionCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupPopover()
        setupStatusItem()
        setupBindings()

        _ = ClipHistoryStore.shared
        SelectionMonitor.shared.start()

        if !AccessibilityInspector.shared.isTrusted {
            AccessibilityInspector.shared.requestPermissionPrompt()
            startPermissionPolling()
        }
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 380, height: 450)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverView())
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateStatusBarIcon(flashingCopy: false)
    }

    private func setupBindings() {
        SelectionMonitor.shared.$runtimeState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarIcon(flashingCopy: false)
            }
            .store(in: &cancellables)

        SelectionMonitor.shared.onAutoClip = { [weak self] _ in
            DispatchQueue.main.async {
                self?.flashStatusBarIcon()
            }
        }
    }

    private func startPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AccessibilityInspector.shared.isTrusted {
                timer.invalidate()
                self?.permissionCheckTimer = nil
                SelectionMonitor.shared.refreshRuntimeState()
                self?.updateStatusBarIcon(flashingCopy: false)
            }
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        SelectionMonitor.shared.refreshRuntimeState()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.closePopover(nil)
            }
        }
    }

    private func closePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func flashStatusBarIcon() {
        iconResetWorkItem?.cancel()
        updateStatusBarIcon(flashingCopy: true)

        let work = DispatchWorkItem { [weak self] in
            self?.updateStatusBarIcon(flashingCopy: false)
        }
        iconResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: work)
    }

    private func updateStatusBarIcon(flashingCopy: Bool) {
        guard let button = statusItem.button else { return }

        let symbolName: String
        if flashingCopy {
            symbolName = "checkmark.circle.fill"
        } else {
            switch SelectionMonitor.shared.runtimeState {
            case .needsAccessibilityPermission:
                symbolName = "exclamationmark.triangle"
            case .pausedByUser:
                symbolName = "pause.rectangle"
            case .terminalAutoPaused:
                symbolName = "terminal"
            case .guardBlocked:
                symbolName = "shield.lefthalf.filled"
            case .active:
                symbolName = "doc.on.clipboard"
            }
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Markr") {
            image.isTemplate = true
            button.image = image
            button.title = ""
        } else {
            button.title = flashingCopy ? "✓" : "M"
        }
    }
}
