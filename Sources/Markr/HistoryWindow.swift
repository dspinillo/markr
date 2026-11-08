import AppKit
import SwiftUI

final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    private init() {}

    func showWindow() {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = HistoryWindowView()
        let hostingController = NSHostingController(rootView: contentView)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "Markr — Histórico Completo"
        win.titlebarAppearsTransparent = true
        win.backgroundColor = NSColor(red: 0.027, green: 0.031, blue: 0.039, alpha: 1.0)
        win.appearance = NSAppearance(named: .darkAqua)
        win.minSize = NSSize(width: 640, height: 420)
        win.contentViewController = hostingController
        win.isReleasedWhenClosed = false
        win.center()

        self.window = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }
}

struct HistoryWindowView: View {
    @ObservedObject var history = ClipHistoryStore.shared

    @State private var searchText: String = ""
    @State private var selectedAppFilter: String = "Todos"
    @State private var selectedItemId: UUID? = nil
    @State private var copiedFeedbackId: UUID? = nil

    private var availableApps: [String] {
        let apps = Set(history.items.map { $0.origin.appName })
        return ["Todos"] + apps.sorted()
    }

    private var filteredItems: [ClipItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return history.items.filter { item in
            let matchesApp = (selectedAppFilter == "Todos") || (item.origin.appName == selectedAppFilter)
            guard matchesApp else { return false }
            guard !query.isEmpty else { return true }
            return item.text.lowercased().contains(query)
                || item.origin.appName.lowercased().contains(query)
                || (item.origin.sourceURL?.lowercased().contains(query) ?? false)
                || (item.origin.windowTitle?.lowercased().contains(query) ?? false)
        }
    }

    private var selectedItem: ClipItem? {
        if let id = selectedItemId, let found = filteredItems.first(where: { $0.id == id }) {
            return found
        }
        return filteredItems.first
    }

    var body: some View {
        VStack(spacing: 0) {
            topSearchAndFilterBar
            Divider().overlay(RaycastTheme.hairline)

            HStack(spacing: 0) {
                leftListColumn
                    .frame(width: 340)

                Divider().overlay(RaycastTheme.hairline)

                rightDetailColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider().overlay(RaycastTheme.hairline)
            bottomStatusBar
        }
        .background(RaycastTheme.canvas)
        .preferredColorScheme(.dark)
        .onAppear {
            selectedItemId = history.currentClip?.id ?? history.items.first?.id
        }
    }

    // MARK: - Top Search & App Filter Bar

    private var topSearchAndFilterBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(RaycastTheme.muted)

                TextField("Buscar por texto, aplicativo, janela ou URL...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .foregroundColor(RaycastTheme.ink)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(RaycastTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RaycastTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RaycastTheme.hairline, lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableApps, id: \.self) { app in
                        let isSelected = (selectedAppFilter == app)
                        Button {
                            selectedAppFilter = app
                        } label: {
                            Text(app)
                                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? .black : RaycastTheme.body)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isSelected ? Color.white : RaycastTheme.card)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.white : RaycastTheme.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 12)
        .background(RaycastTheme.surface)
    }

    // MARK: - Left Column (Chronological List)

    private var leftListColumn: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 24))
                        .foregroundColor(RaycastTheme.ash)
                    Text("Nenhum item encontrado")
                        .font(.system(size: 12.5))
                        .foregroundColor(RaycastTheme.muted)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            listRow(item)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(RaycastTheme.canvas)
    }

    private func listRow(_ item: ClipItem) -> some View {
        let isSelected = (selectedItem?.id == item.id)
        let isActiveClip = (history.activeClipId == item.id)
        let isJustCopied = (copiedFeedbackId == item.id)

        return HStack(alignment: .top, spacing: 9) {
            appIconView(bundleId: item.origin.bundleId)
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if isActiveClip {
                        Circle()
                            .fill(RaycastTheme.green)
                            .frame(width: 6, height: 6)
                    }

                    Text(item.origin.displaySubtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RaycastTheme.body)
                        .lineLimit(1)

                    Spacer()

                    if isJustCopied {
                        Text("✓ Copiado")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(RaycastTheme.green)
                    } else {
                        Text(Self.shortDateTime(from: item.createdAt))
                            .font(.system(size: 10.5))
                            .foregroundColor(RaycastTheme.ash)
                    }
                }

                Text(item.singleLinePreview)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(RaycastTheme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? RaycastTheme.cardHover : RaycastTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isJustCopied
                        ? RaycastTheme.green.opacity(0.6)
                        : (isSelected ? Color.white.opacity(0.28) : RaycastTheme.hairline),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItemId = item.id
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                triggerCopy(item)
            }
        )
    }

    // MARK: - Right Column (Detail & Full Origin Inspector)

    private var rightDetailColumn: some View {
        Group {
            if let item = selectedItem {
                VStack(alignment: .leading, spacing: 12) {
                    // Origin & Actions Header
                    HStack(alignment: .center, spacing: 10) {
                        appIconView(bundleId: item.origin.bundleId)
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.origin.appName)
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundColor(RaycastTheme.ink)

                                Text(item.trigger.badgeTitle)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(item.trigger == .autoSelect ? RaycastTheme.green : RaycastTheme.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(
                                        (item.trigger == .autoSelect ? RaycastTheme.green : RaycastTheme.blue).opacity(0.14)
                                    )
                                    .clipShape(Capsule())
                            }

                            Text(Self.fullDateTime(from: item.createdAt))
                                .font(.system(size: 11))
                                .foregroundColor(RaycastTheme.muted)
                        }

                        Spacer()

                        Button {
                            triggerCopy(item)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: copiedFeedbackId == item.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .bold))
                                Text(copiedFeedbackId == item.id ? "Copiado!" : "Copiar")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            history.removeItem(item)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(RaycastTheme.red)
                                .frame(width: 28, height: 28)
                                .background(RaycastTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(RaycastTheme.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Excluir este item do histórico")
                    }

                    // Origin URL / Window Info Card
                    if item.origin.sourceURL != nil || item.origin.windowTitle != nil {
                        VStack(alignment: .leading, spacing: 5) {
                            if let winTitle = item.origin.windowTitle, !winTitle.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "macwindow")
                                        .font(.system(size: 11))
                                        .foregroundColor(RaycastTheme.muted)
                                    Text(winTitle)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(RaycastTheme.body)
                                        .lineLimit(1)
                                }
                            }

                            if let rawURL = item.origin.sourceURL, let url = URL(string: rawURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 11))
                                        .foregroundColor(RaycastTheme.blue)

                                    Text(rawURL)
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundColor(RaycastTheme.blue)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Button {
                                        NSWorkspace.shared.open(url)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Text("Abrir site")
                                            Image(systemName: "arrow.up.right")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(RaycastTheme.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(10)
                        .background(RaycastTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(RaycastTheme.hairline, lineWidth: 1)
                        )
                    }

                    // Full Scrollable Text Content
                    ScrollView {
                        Text(item.text)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundColor(RaycastTheme.ink)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(RaycastTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(RaycastTheme.hairline, lineWidth: 1)
                    )
                }
                .padding(16)
            } else {
                VStack {
                    Spacer()
                    Text("Selecione um item à esquerda para ver os detalhes")
                        .font(.system(size: 12.5))
                        .foregroundColor(RaycastTheme.muted)
                    Spacer()
                }
            }
        }
        .background(RaycastTheme.canvas)
    }

    // MARK: - Bottom Bar

    private var bottomStatusBar: some View {
        HStack {
            Text("\(filteredItems.count) de \(history.items.count) itens • Dica: duplo clique num item da lista copia direto")
                .font(.system(size: 11))
                .foregroundColor(RaycastTheme.ash)

            Spacer()

            if !history.items.isEmpty {
                Button("Limpar todo o histórico") {
                    history.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(RaycastTheme.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(RaycastTheme.surface)
    }

    // MARK: - Helpers

    private func triggerCopy(_ item: ClipItem) {
        history.copyItemToPasteboard(item)
        copiedFeedbackId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            if copiedFeedbackId == item.id {
                copiedFeedbackId = nil
            }
        }
    }

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

    private static func shortDateTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 10 { return "agora" }
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func fullDateTime(from date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "pt_BR")
        dayFormatter.dateFormat = "dd"

        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "pt_BR")
        monthFormatter.dateFormat = "MMMM"

        let restFormatter = DateFormatter()
        restFormatter.locale = Locale(identifier: "pt_BR")
        restFormatter.dateFormat = "yyyy 'às' HH:mm:ss"

        let day = dayFormatter.string(from: date)
        let rawMonth = monthFormatter.string(from: date)
        let capitalizedMonth = rawMonth.prefix(1).uppercased() + rawMonth.dropFirst()
        let rest = restFormatter.string(from: date)
        return "\(day) de \(capitalizedMonth) de \(rest)"
    }
}
