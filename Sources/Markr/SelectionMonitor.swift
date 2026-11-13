import AppKit
import Combine

final class SelectionMonitor: ObservableObject {
    static let shared = SelectionMonitor()

    @Published private(set) var runtimeState: RuntimeState = .active
    @Published private(set) var lastDiagnosticMessage: String = "Pronto para marcar e copiar"
    @Published private(set) var activeExternalAppName: String?
    @Published private(set) var activeExternalBundleId: String?
    @Published private(set) var isActiveExternalAppTerminal: Bool = false

    var onAutoClip: ((ClipItem) -> Void)?

    private var globalMouseMonitor: Any?
    private var mouseDownPoint: CGPoint?
    private var maxDragDistance: CGFloat = 0
    private var wasEditableAtMouseDown: Bool = false
    private var activeSelectionToken: UUID = UUID()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        Settings.shared.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshRuntimeState()
            }
            .store(in: &cancellables)

        Settings.shared.$terminalAutoPause
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshRuntimeState()
            }
            .store(in: &cancellables)
    }

    func start() {
        stop()
        observeWorkspaceActivation()
        refreshFrontmostApp(NSWorkspace.shared.frontmostApplication)

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    func stop() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    func refreshRuntimeState() {
        if !AccessibilityInspector.shared.isTrusted {
            runtimeState = .needsAccessibilityPermission
            return
        }
        if !Settings.shared.isEnabled {
            runtimeState = .pausedByUser
            return
        }
        if Settings.shared.terminalAutoPause && isActiveExternalAppTerminal {
            runtimeState = .terminalAutoPaused(appName: activeExternalAppName ?? "Terminal")
            return
        }
        runtimeState = .active
    }

    // MARK: - Workspace Tracking

    private func observeWorkspaceActivation() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.refreshFrontmostApp(app)
        }
    }

    private func refreshFrontmostApp(_ app: NSRunningApplication?) {
        guard let app = app, app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        let name = app.localizedName ?? "App"
        let bundleId = app.bundleIdentifier
        activeExternalAppName = name
        activeExternalBundleId = bundleId
        isActiveExternalAppTerminal = Settings.shared.isTerminalApp(bundleId: bundleId, appName: name)

        if Settings.shared.terminalAutoPause && isActiveExternalAppTerminal {
            runtimeState = .terminalAutoPaused(appName: name)
            lastDiagnosticMessage = "Modo passivo no \(name) (cópia nativa preservada)"
        } else {
            if !Settings.shared.isAppManuallyIgnored(bundleId: bundleId) {
                AccessibilityInspector.shared.warmUpApplicationIfNeeded(pid: app.processIdentifier)
            }
            refreshRuntimeState()
        }
    }

    // MARK: - Mouse Event Pipeline

    private func handleMouseEvent(_ event: NSEvent) {
        guard Settings.shared.isEnabled else { return }
        guard AccessibilityInspector.shared.isTrusted else {
            refreshRuntimeState()
            return
        }

        let quartzPoint = event.cgEvent?.location ?? Self.quartzPoint(from: NSEvent.mouseLocation)

        switch event.type {
        case .leftMouseDown:
            mouseDownPoint = quartzPoint
            maxDragDistance = 0
            activeSelectionToken = UUID()

            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                wasEditableAtMouseDown = false
                return
            }

            let appName = frontApp.localizedName
            let bundleId = frontApp.bundleIdentifier

            // 1. TerminalAutoPause: do not touch mouse selection in Terminal/Herdr
            if Settings.shared.terminalAutoPause && Settings.shared.isTerminalApp(bundleId: bundleId, appName: appName) {
                wasEditableAtMouseDown = false
                return
            }

            // 2. Manual Per-App Ignore
            if Settings.shared.isAppManuallyIgnored(bundleId: bundleId) {
                wasEditableAtMouseDown = false
                return
            }

            let pid = frontApp.processIdentifier
            AccessibilityInspector.shared.warmUpApplicationIfNeeded(pid: pid)
            wasEditableAtMouseDown = AccessibilityInspector.shared.isPointInEditableElement(
                screenPoint: quartzPoint,
                pid: pid
            )

        case .leftMouseDragged:
            guard let downPoint = mouseDownPoint else { return }
            let dist = hypot(quartzPoint.x - downPoint.x, quartzPoint.y - downPoint.y)
            if dist > maxDragDistance {
                maxDragDistance = dist
            }

        case .leftMouseUp:
            guard let downPoint = mouseDownPoint else { return }
            let upPoint = quartzPoint
            let dragDist = maxDragDistance
            let clickCount = event.clickCount
            let flags = event.modifierFlags
            let downWasEditable = wasEditableAtMouseDown
            let token = activeSelectionToken

            mouseDownPoint = nil
            maxDragDistance = 0

            if flags.contains(.command) || flags.contains(.control) {
                return
            }

            let isDragGesture = Settings.shared.copyOnDrag && dragDist >= 6.0
            let isMultiClickGesture = Settings.shared.copyOnMultiClick && clickCount >= 2
            let isShiftClickGesture = Settings.shared.copyOnDrag && flags.contains(.shift)

            guard isDragGesture || isMultiClickGesture || isShiftClickGesture else {
                return
            }

            guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
            let appName = frontApp.localizedName ?? "App"
            let bundleId = frontApp.bundleIdentifier

            if Settings.shared.terminalAutoPause && Settings.shared.isTerminalApp(bundleId: bundleId, appName: appName) {
                runtimeState = .terminalAutoPaused(appName: appName)
                lastDiagnosticMessage = "Modo passivo no \(appName) (cópia nativa ativa)"
                return
            }

            if Settings.shared.isAppManuallyIgnored(bundleId: bundleId) {
                lastDiagnosticMessage = "Ignorado em \(appName) (lista de exceções)"
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.065) { [weak self] in
                guard let self = self, self.activeSelectionToken == token else { return }
                self.evaluateSelection(
                    downPoint: downPoint,
                    upPoint: upPoint,
                    downWasEditable: downWasEditable,
                    token: token,
                    isRetry: false
                )
            }

        default:
            break
        }
    }

    private func evaluateSelection(
        downPoint: CGPoint,
        upPoint: CGPoint,
        downWasEditable: Bool,
        token: UUID,
        isRetry: Bool
    ) {
        guard activeSelectionToken == token else { return }

        guard let inspection = AccessibilityInspector.shared.inspectSelection(
            mouseDownScreenPoint: downPoint,
            mouseUpScreenPoint: upPoint
        ) else {
            return
        }

        let isEditable = inspection.isEditable || downWasEditable

        // Core EditableGuard Protection
        if Settings.shared.ignoreEditableFields && isEditable {
            runtimeState = .guardBlocked(appName: inspection.origin.appName, role: inspection.primaryRole)
            lastDiagnosticMessage = "Protegido: campo editável em \(inspection.origin.appName) (\(inspection.primaryRole))"
            return
        }

        if let axText = inspection.selectedText,
           !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runtimeState = .active
            performRichCopyOrFallback(
                axText: axText,
                origin: inspection.origin,
                token: token
            )
            return
        }

        if !isRetry {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.095) { [weak self] in
                guard let self = self, self.activeSelectionToken == token else { return }
                self.evaluateSelection(
                    downPoint: downPoint,
                    upPoint: upPoint,
                    downWasEditable: downWasEditable,
                    token: token,
                    isRetry: true
                )
            }
        }
    }

    // MARK: - Rich Copy & Fallback

    private func performRichCopyOrFallback(
        axText: String,
        origin: ClipOrigin,
        token: UUID
    ) {
        let pb = NSPasteboard.general
        let initialChangeCount = pb.changeCount

        // Trigger native Copy (Cmd + C) now that AccessibilityInspector confirmed a valid, non-editable selection
        triggerSyntheticCommandC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) { [weak self] in
            guard let self = self, self.activeSelectionToken == token else { return }

            let didNativeCopyUpdatePasteboard = pb.changeCount != initialChangeCount
            let payload: RichCopyPayload
            let alreadyOnPasteboard: Bool

            if didNativeCopyUpdatePasteboard {
                payload = RichClipboardFormatter.captureFromPasteboard(pb, fallbackText: axText)
                alreadyOnPasteboard = true
            } else {
                let cleaned = RichClipboardFormatter.formatPlainText(rawPlain: axText, htmlString: nil)
                payload = RichCopyPayload(plainText: cleaned, htmlData: nil, rtfData: nil)
                alreadyOnPasteboard = false
            }

            if let item = ClipHistoryStore.shared.recordAutoClip(
                text: payload.plainText,
                htmlData: payload.htmlData,
                rtfData: payload.rtfData,
                alreadyOnPasteboard: alreadyOnPasteboard,
                origin: origin
            ) {
                self.lastDiagnosticMessage = "Copiado de \(origin.displaySubtitle)"
                if Settings.shared.playSubtleSound {
                    NSSound(named: NSSound.Name("Tink"))?.play()
                }
                self.onAutoClip?(item)
            } else {
                self.lastDiagnosticMessage = "Já estava no clipboard (\(origin.appName))"
            }
        }
    }

    private func triggerSyntheticCommandC() {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return }
        let cKeyCode: CGKeyCode = 0x08 // 'c' on ANSI/ISO keyboards
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: cKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func quartzPoint(from nsPoint: NSPoint) -> CGPoint {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: nsPoint.x, y: primaryScreenHeight - nsPoint.y)
    }
}
