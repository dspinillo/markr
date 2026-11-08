import SwiftUI
import AppKit

enum RaycastTheme {
    static let canvas = Color(red: 0.027, green: 0.031, blue: 0.039)       // #07080A
    static let surface = Color(red: 0.051, green: 0.051, blue: 0.051)      // #0D0D0D
    static let card = Color(red: 0.063, green: 0.067, blue: 0.067)         // #101111
    static let cardHover = Color(red: 0.090, green: 0.095, blue: 0.098)    // #171819
    static let hairline = Color(red: 0.141, green: 0.153, blue: 0.157)     // #242728
    static let ink = Color(red: 0.957, green: 0.957, blue: 0.965)          // #F4F4F6
    static let body = Color(red: 0.804, green: 0.804, blue: 0.804)         // #CDCDCD
    static let muted = Color(red: 0.612, green: 0.612, blue: 0.616)        // #9C9C9D
    static let ash = Color(red: 0.416, green: 0.420, blue: 0.424)          // #6A6B6C
    static let green = Color(red: 0.349, green: 0.831, blue: 0.600)        // #59D499
    static let blue = Color(red: 0.341, green: 0.757, blue: 1.000)         // #57C1FF
    static let amber = Color(red: 1.000, green: 0.773, blue: 0.200)        // #FFC533
    static let red = Color(red: 1.000, green: 0.380, blue: 0.380)          // #FF6161
}

struct PopoverView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var monitor = SelectionMonitor.shared
    @ObservedObject var history = ClipHistoryStore.shared

    @State private var showSettings: Bool = false
    @State private var copiedFeedbackId: UUID? = nil

    private let recentLimit = 5

    private var recentItems: [ClipItem] {
        Array(history.items.prefix(recentLimit))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().overlay(RaycastTheme.hairline)

            if !AccessibilityInspector.shared.isTrusted {
                permissionBanner
                Divider().overlay(RaycastTheme.hairline)
            }

            if case let .terminalAutoPaused(termName) = monitor.runtimeState {
                terminalAutoPauseBanner(appName: termName)
                Divider().overlay(RaycastTheme.hairline)
            } else if case let .guardBlocked(appName, role) = monitor.runtimeState {
                editableGuardBanner(appName: appName, role: role)
                Divider().overlay(RaycastTheme.hairline)
            }

            currentClipHeroSection
            Divider().overlay(RaycastTheme.hairline)

            recentHistorySection

            if showSettings {
                Divider().overlay(RaycastTheme.hairline)
                settingsDrawer
            }

            Divider().overlay(RaycastTheme.hairline)
            footerBar
        }
        .frame(width: 380)
        .background(RaycastTheme.canvas)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusDotColor.opacity(0.8), radius: 4)

            Text("Markr")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(RaycastTheme.ink)

            Text(statusBadgeText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusDotColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(statusDotColor.opacity(0.14))
                .clipShape(Capsule())

            Spacer()

            Button {
                settings.isEnabled.toggle()
            } label: {
                Text(settings.isEnabled ? "Ativo" : "Pausado")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(settings.isEnabled ? RaycastTheme.green : RaycastTheme.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(settings.isEnabled ? RaycastTheme.green.opacity(0.15) : RaycastTheme.card)
                    )
                    .overlay(
                        Capsule()
                            .stroke(settings.isEnabled ? RaycastTheme.green.opacity(0.35) : RaycastTheme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "slider.horizontal.3" : "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(showSettings ? RaycastTheme.ink : RaycastTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(RaycastTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RaycastTheme.hairline, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Regras e Preferências")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RaycastTheme.surface)
    }

    private var statusDotColor: Color {
        switch monitor.runtimeState {
        case .active: return RaycastTheme.green
        case .terminalAutoPaused: return RaycastTheme.blue
        case .guardBlocked: return RaycastTheme.amber
        case .pausedByUser: return RaycastTheme.ash
        case .needsAccessibilityPermission: return RaycastTheme.amber
        }
    }

    private var statusBadgeText: String {
        switch monitor.runtimeState {
        case .active: return "Marcou, copiou"
        case .terminalAutoPaused(let name): return "Passivo · \(name)"
        case .guardBlocked: return "Input protegido"
        case .pausedByUser: return "Pausado"
        case .needsAccessibilityPermission: return "Permissão AX"
        }
    }

    // MARK: - Contextual Banners

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(RaycastTheme.amber)
                .font(.system(size: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text("Permissão de Acessibilidade necessária")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(RaycastTheme.ink)
                Text("Ative o Markr em Privacidade e Segurança > Acessibilidade.")
                    .font(.system(size: 10.5))
                    .foregroundColor(RaycastTheme.muted)
            }

            Spacer()

            Button {
                AccessibilityInspector.shared.requestPermissionPrompt()
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Liberar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(RaycastTheme.amber.opacity(0.08))
    }

    private func terminalAutoPauseBanner(appName: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 11))
                .foregroundColor(RaycastTheme.blue)
            Text("No **\(appName)** o Markr fica 100% em pausa para não sobrepor a cópia nativa do terminal.")
                .font(.system(size: 11))
                .foregroundColor(RaycastTheme.body)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RaycastTheme.blue.opacity(0.08))
    }

    private func editableGuardBanner(appName: String, role: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 11))
                .foregroundColor(RaycastTheme.amber)
            Text("Cópia bloqueada em **\(appName)** (`\(role)`) — seu clipboard atual foi preservado para você colar com ⌘V.")
                .font(.system(size: 11))
                .foregroundColor(RaycastTheme.body)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RaycastTheme.amber.opacity(0.08))
    }

    // MARK: - Current Clip Hero + Undo CTA

    private var currentClipHeroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let current = history.currentClip {
                HStack(spacing: 6) {
                    appIconView(bundleId: current.origin.bundleId)
                        .frame(width: 15, height: 15)

                    Text(current.origin.displaySubtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(RaycastTheme.muted)
                        .lineLimit(1)

                    if let rawURL = current.origin.sourceURL, let url = URL(string: rawURL) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundColor(RaycastTheme.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Abrir URL de origem: \(rawURL)")
                    }

                    Spacer()

                    Text(current.trigger.badgeTitle)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(current.trigger == .autoSelect ? RaycastTheme.green : RaycastTheme.blue)
                }

                Text(current.singleLinePreview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(RaycastTheme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .background(RaycastTheme.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RaycastTheme.hairline, lineWidth: 1)
                    )

                if let prev = history.previousClip {
                    HStack(spacing: 8) {
                        Text("Anterior: \"\(String(prev.singleLinePreview.prefix(24)))\"")
                            .font(.system(size: 11))
                            .foregroundColor(RaycastTheme.muted)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            _ = history.restorePreviousClip()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Desfazer")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3.5)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Restaurar o texto que estava no clipboard antes desta cópia")
                    }
                }
            } else {
                HStack {
                    Image(systemName: "scissors")
                        .foregroundColor(RaycastTheme.muted)
                    Text("Selecione qualquer texto na tela para copiar automaticamente.")
                        .font(.system(size: 12))
                        .foregroundColor(RaycastTheme.muted)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(12)
        .background(RaycastTheme.card)
    }

    // MARK: - Compact Recent Clips + "Ver histórico completo"

    private var recentHistorySection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ÚLTIMOS COPIADOS (\(recentItems.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(RaycastTheme.ash)

                Spacer()

                Button {
                    HistoryWindowController.shared.showWindow()
                } label: {
                    HStack(spacing: 3) {
                        Text("Ver histórico completo (\(history.items.count))")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(RaycastTheme.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(RaycastTheme.surface)

            Divider().overlay(RaycastTheme.hairline)

            if recentItems.isEmpty {
                VStack {
                    Text("Nenhum clip registrado ainda")
                        .font(.system(size: 12))
                        .foregroundColor(RaycastTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(recentItems) { item in
                            historyRow(item)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 175)
            }

            Divider().overlay(RaycastTheme.hairline)

            Button {
                HistoryWindowController.shared.showWindow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("Abrir Histórico Completo e Busca")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(history.items.count) itens")
                        .font(.system(size: 11))
                        .foregroundColor(RaycastTheme.muted)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11))
                }
                .foregroundColor(RaycastTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RaycastTheme.card)
            }
            .buttonStyle(.plain)
        }
    }

    private func historyRow(_ item: ClipItem) -> some View {
        let isJustCopied = (copiedFeedbackId == item.id)
        let isActiveInClipboard = (history.activeClipId == item.id)

        return HStack(alignment: .top, spacing: 9) {
            appIconView(bundleId: item.origin.bundleId)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isActiveInClipboard {
                        Circle()
                            .fill(RaycastTheme.green)
                            .frame(width: 6, height: 6)
                            .help("Atualmente no clipboard")
                    }

                    Text(item.origin.displaySubtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RaycastTheme.body)
                        .lineLimit(1)

                    if let rawURL = item.origin.sourceURL, let url = URL(string: rawURL) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(RaycastTheme.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Abrir \(rawURL)")
                    }

                    Spacer()

                    if isJustCopied {
                        Text("✓ Copiado")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(RaycastTheme.green)
                    } else {
                        Text(Self.relativeTime(from: item.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(RaycastTheme.ash)
                    }
                }

                Text(item.singleLinePreview)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(RaycastTheme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isJustCopied ? RaycastTheme.green.opacity(0.12) : RaycastTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isJustCopied
                        ? RaycastTheme.green.opacity(0.55)
                        : (isActiveInClipboard ? RaycastTheme.green.opacity(0.32) : RaycastTheme.hairline),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            history.copyItemToPasteboard(item)
            copiedFeedbackId = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                if copiedFeedbackId == item.id {
                    copiedFeedbackId = nil
                }
            }
        }
    }

    // MARK: - Settings Drawer

    private var settingsDrawer: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("REGRAS E PROTEÇÕES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(RaycastTheme.ash)
                .padding(.bottom, 2)

            Toggle("Ignorar campos de texto editáveis (Evita loop)", isOn: $settings.ignoreEditableFields)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundColor(RaycastTheme.body)

            Toggle("Auto-Pause em Terminais (Herdr / Terminal.app)", isOn: $settings.terminalAutoPause)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundColor(RaycastTheme.body)

            HStack(spacing: 16) {
                Toggle("Arrastar mouse", isOn: $settings.copyOnDrag)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 12))
                    .foregroundColor(RaycastTheme.body)

                Toggle("Duplo/triplo clique", isOn: $settings.copyOnMultiClick)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 12))
                    .foregroundColor(RaycastTheme.body)
            }

            HStack(spacing: 16) {
                Toggle("Som sutil", isOn: $settings.playSubtleSound)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.system(size: 12))
                    .foregroundColor(RaycastTheme.body)

                Toggle(
                    "Iniciar no login",
                    isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.launchAtLogin = $0 }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundColor(RaycastTheme.body)
            }

            if let appName = monitor.activeExternalAppName,
               let bundleId = monitor.activeExternalBundleId,
               !monitor.isActiveExternalAppTerminal {
                let isIgnored = settings.isAppManuallyIgnored(bundleId: bundleId)
                HStack {
                    Text("App atual: \(appName)")
                        .font(.system(size: 11.5))
                        .foregroundColor(RaycastTheme.muted)
                    Spacer()
                    Button {
                        settings.toggleIgnoreApp(bundleId: bundleId)
                    } label: {
                        Text(isIgnored ? "Reativar neste App" : "Ignorar este App")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isIgnored ? RaycastTheme.amber : RaycastTheme.body)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RaycastTheme.canvas)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(RaycastTheme.hairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RaycastTheme.surface)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Text(monitor.lastDiagnosticMessage)
                .font(.system(size: 10.5))
                .foregroundColor(RaycastTheme.ash)
                .lineLimit(1)

            Spacer()

            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundColor(RaycastTheme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RaycastTheme.surface)
    }

    // MARK: - Helpers

    private func appIconView(bundleId: String?) -> some View {
        Group {
            if let bundleId = bundleId,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .foregroundColor(RaycastTheme.muted)
            }
        }
    }

    private static func relativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 10 { return "agora" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}
