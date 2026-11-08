import Foundation
import Combine
import ServiceManagement

final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "markr.isEnabled"
        static let ignoreEditableFields = "markr.ignoreEditableFields"
        static let terminalAutoPause = "markr.terminalAutoPause"
        static let copyOnDrag = "markr.copyOnDrag"
        static let copyOnMultiClick = "markr.copyOnMultiClick"
        static let playSubtleSound = "markr.playSubtleSound"
        static let ignoredBundleIds = "markr.ignoredBundleIds"
    }

    static let knownTerminalBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "com.github.wez.wezterm",
        "com.cmuxterm.app",
        "co.zeit.hyper"
    ]

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var ignoreEditableFields: Bool {
        didSet { defaults.set(ignoreEditableFields, forKey: Keys.ignoreEditableFields) }
    }

    @Published var terminalAutoPause: Bool {
        didSet { defaults.set(terminalAutoPause, forKey: Keys.terminalAutoPause) }
    }

    @Published var copyOnDrag: Bool {
        didSet { defaults.set(copyOnDrag, forKey: Keys.copyOnDrag) }
    }

    @Published var copyOnMultiClick: Bool {
        didSet { defaults.set(copyOnMultiClick, forKey: Keys.copyOnMultiClick) }
    }

    @Published var playSubtleSound: Bool {
        didSet { defaults.set(playSubtleSound, forKey: Keys.playSubtleSound) }
    }

    @Published var ignoredBundleIds: Set<String> {
        didSet { defaults.set(Array(ignoredBundleIds).sorted(), forKey: Keys.ignoredBundleIds) }
    }

    private init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.ignoreEditableFields: true,
            Keys.terminalAutoPause: true,
            Keys.copyOnDrag: true,
            Keys.copyOnMultiClick: true,
            Keys.playSubtleSound: false,
            Keys.ignoredBundleIds: []
        ])

        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.ignoreEditableFields = defaults.bool(forKey: Keys.ignoreEditableFields)
        self.terminalAutoPause = defaults.bool(forKey: Keys.terminalAutoPause)
        self.copyOnDrag = defaults.bool(forKey: Keys.copyOnDrag)
        self.copyOnMultiClick = defaults.bool(forKey: Keys.copyOnMultiClick)
        self.playSubtleSound = defaults.bool(forKey: Keys.playSubtleSound)
        self.ignoredBundleIds = Set(defaults.stringArray(forKey: Keys.ignoredBundleIds) ?? [])
    }

    func isTerminalApp(bundleId: String?, appName: String?) -> Bool {
        if let bundleId = bundleId, Self.knownTerminalBundleIds.contains(bundleId) {
            return true
        }
        if let name = appName?.lowercased() {
            let terminalTokens = ["terminal", "herdr", "iterm", "ghostty", "warp", "kitty", "alacritty", "wezterm"]
            if terminalTokens.contains(where: { name.contains($0) }) {
                return true
            }
        }
        return false
    }

    func isAppManuallyIgnored(bundleId: String?) -> Bool {
        guard let bundleId = bundleId else { return false }
        if bundleId == Bundle.main.bundleIdentifier { return true }
        return ignoredBundleIds.contains(bundleId)
    }

    func toggleIgnoreApp(bundleId: String) {
        if ignoredBundleIds.contains(bundleId) {
            ignoredBundleIds.remove(bundleId)
        } else {
            ignoredBundleIds.insert(bundleId)
        }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Ignore if running unsigned or outside /Applications
            }
        }
    }
}
