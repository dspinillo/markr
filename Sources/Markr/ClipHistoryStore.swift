import AppKit
import Combine

final class ClipHistoryStore: ObservableObject {
    static let shared = ClipHistoryStore()

    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var activeClipId: UUID?
    @Published private(set) var previousActiveClipId: UUID?

    private let maxItems = 300
    private var pollTimer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let storageURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Markr", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.storageURL = dir.appendingPathComponent("history.json")
        loadFromDisk()
        // Remove any legacy terminal entries if terminalAutoPause is enabled
        if Settings.shared.terminalAutoPause {
            items.removeAll {
                Settings.shared.isTerminalApp(bundleId: $0.origin.bundleId, appName: $0.origin.appName)
            }
            saveToDisk()
        }
        self.activeClipId = items.first?.id
        self.previousActiveClipId = items.count > 1 ? items[1].id : nil
    }

    var currentClip: ClipItem? {
        if let activeId = activeClipId, let found = items.first(where: { $0.id == activeId }) {
            return found
        }
        return items.first
    }

    var previousClip: ClipItem? {
        if let prevId = previousActiveClipId,
           prevId != activeClipId,
           let found = items.first(where: { $0.id == prevId }) {
            return found
        }
        if let current = currentClip,
           let idx = items.firstIndex(where: { $0.id == current.id }),
           idx + 1 < items.count {
            return items[idx + 1]
        }
        return nil
    }

    func startClipboardWatcher() {
        pollTimer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.checkExternalClipboardChange()
        }
    }

    /// Called by SelectionMonitor when Markr automatically copies selected text
    @discardableResult
    func recordAutoClip(text: String, origin: ClipOrigin) -> ClipItem? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let pb = NSPasteboard.general
        if pb.string(forType: .string) == text, currentClip?.text == text {
            return nil
        }

        pb.clearContents()
        pb.setString(text, forType: .string)
        lastChangeCount = pb.changeCount

        let item = ClipItem(text: text, origin: origin, trigger: .autoSelect)
        prependNewCapture(item)
        return item
    }

    /// Restores the clip immediately prior to the current one ("↩ Desfazer") without altering history order or dates
    func restorePreviousClip() -> Bool {
        guard let prev = previousClip else { return false }
        copyItemToPasteboard(prev)
        return true
    }

    /// Copies a history item back to the system clipboard WITHOUT changing its position or timestamp in history
    func copyItemToPasteboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.text, forType: .string)
        lastChangeCount = pb.changeCount

        if activeClipId != item.id {
            previousActiveClipId = activeClipId
            activeClipId = item.id
        }
    }

    func removeItem(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        if activeClipId == item.id {
            activeClipId = items.first?.id
        }
        if previousActiveClipId == item.id {
            previousActiveClipId = items.count > 1 ? items[1].id : nil
        }
        saveToDisk()
    }

    func clearHistory() {
        items.removeAll()
        activeClipId = nil
        previousActiveClipId = nil
        saveToDisk()
    }

    // MARK: - Internal

    private func checkExternalClipboardChange() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if currentClip?.text == text {
            return
        }

        let origin = AccessibilityInspector.shared.captureCurrentOrigin()
        let item = ClipItem(text: text, origin: origin, trigger: .manualOrNative)
        prependNewCapture(item)
    }

    private func prependNewCapture(_ item: ClipItem) {
        previousActiveClipId = activeClipId ?? items.first?.id
        items.insert(item, at: 0)
        activeClipId = item.id
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        saveToDisk()
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // Non-fatal persistence error
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return
        }
        self.items = decoded
    }
}
