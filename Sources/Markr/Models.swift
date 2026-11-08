import Foundation

enum ClipTrigger: String, Codable {
    case autoSelect = "auto"
    case manualOrNative = "native"

    var badgeTitle: String {
        switch self {
        case .autoSelect: return "✦ Auto"
        case .manualOrNative: return "⌘ Nativo"
        }
    }
}

struct ClipOrigin: Codable, Equatable {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let sourceURL: String?

    var sourceDomain: String? {
        guard let raw = sourceURL, let url = URL(string: raw), let host = url.host else {
            return nil
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var displaySubtitle: String {
        if let domain = sourceDomain, !domain.isEmpty {
            return "\(appName) · \(domain)"
        }
        if let title = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           title.lowercased() != appName.lowercased() {
            let shortTitle = title.count > 34 ? String(title.prefix(34)) + "…" : title
            return "\(appName) · \(shortTitle)"
        }
        return appName
    }
}

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let origin: ClipOrigin
    let trigger: ClipTrigger
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        origin: ClipOrigin,
        trigger: ClipTrigger,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.origin = origin
        self.trigger = trigger
        self.createdAt = createdAt
    }

    var singleLinePreview: String {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}

enum RuntimeState: Equatable {
    case active
    case pausedByUser
    case terminalAutoPaused(appName: String)
    case guardBlocked(appName: String, role: String)
    case needsAccessibilityPermission
}
