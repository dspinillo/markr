import AppKit
import SwiftUI

enum Theme {
    static let bg = Color(red: 0.04, green: 0.045, blue: 0.055)
    static let canvas = Color(red: 0.027, green: 0.031, blue: 0.039)
    static let surface = Color(red: 0.051, green: 0.051, blue: 0.051)
    static let card = Color(red: 0.063, green: 0.067, blue: 0.067)
    static let cardHover = Color(red: 0.090, green: 0.095, blue: 0.098)
    static let hairline = Color(red: 0.141, green: 0.153, blue: 0.157)
    static let ink = Color(red: 0.957, green: 0.957, blue: 0.965)
    static let body = Color(red: 0.804, green: 0.804, blue: 0.804)
    static let muted = Color(red: 0.612, green: 0.612, blue: 0.616)
    static let ash = Color(red: 0.416, green: 0.420, blue: 0.424)
    static let green = Color(red: 0.349, green: 0.831, blue: 0.600)
    static let blue = Color(red: 0.341, green: 0.757, blue: 1.000)
    static let amber = Color(red: 1.000, green: 0.773, blue: 0.200)
    static let red = Color(red: 1.000, green: 0.380, blue: 0.380)
}

@MainActor
func saveView<V: View>(_ view: V, to path: String, scale: CGFloat = 2.0) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    guard let cgImage = renderer.cgImage else {
        print("Erro ao renderizar \(path)")
        return
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("📸 Salvo: \(path)")
    }
}

// MARK: - 1. Hero Banner View

struct HeroBannerView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.065, blue: 0.080),
                    Color(red: 0.025, green: 0.028, blue: 0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 42) {
                // Left: App Icon + Title + Pitch
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 18) {
                        appSquircleIcon
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Markr")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Theme.ink)
                                Text("macOS Menu Bar")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Theme.green)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3)
                                    .background(Theme.green.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            Text("Marcou na tela, já está no clipboard — sem tropeçar em inputs nem brigar com o terminal.")
                                .font(.system(size: 14.5))
                                .foregroundColor(Theme.muted)
                        }
                    }

                    // 4 Menu Bar state pills
                    HStack(spacing: 10) {
                        statePill(icon: "doc.on.clipboard", label: "Ativo no Sistema", color: Theme.ink)
                        statePill(icon: "checkmark.circle.fill", label: "Copiado na Hora", color: Theme.green)
                        statePill(icon: "shield.lefthalf.filled", label: "Trava em Inputs", color: Theme.amber)
                        statePill(icon: "terminal", label: "Auto-Pause no Herdr", color: Theme.blue)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 36)
        }
        .frame(width: 960, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }

    private var appSquircleIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.11, green: 0.13, blue: 0.15), Color(red: 0.035, green: 0.04, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 76, height: 76)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            VStack(spacing: 7) {
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 30, height: 4.5)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.green.opacity(0.22))
                        .frame(width: 44, height: 15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.green, lineWidth: 1.5)
                        )
                    Capsule().fill(Theme.green).frame(width: 34, height: 5)

                    // Left white pin handle
                    VStack(spacing: 0) {
                        Circle().fill(Color.white).frame(width: 5.5, height: 5.5)
                        Rectangle().fill(Color.white).frame(width: 2, height: 15)
                    }
                    .offset(x: -22, y: -3)

                    // Right white pin handle
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.white).frame(width: 2, height: 15)
                        Circle().fill(Color.white).frame(width: 5.5, height: 5.5)
                    }
                    .offset(x: 22, y: 3)
                }
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 22, height: 4.5)
            }
        }
    }

    private func statePill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.body)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - 2. Popover States View (Side-by-Side)

struct PopoverShowcaseView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            popoverCard(
                caption: "1 · FORA DO TERMINAL (MARCOU, COPIOU)",
                menuBarSymbol: "checkmark.circle.fill",
                dotColor: Theme.green,
                badge: "Marcou, copiou",
                banner: nil,
                bannerIcon: "",
                bannerColor: Theme.green,
                heroApp: "Google Chrome · blog.cloudflare.com",
                heroHasLink: true,
                heroText: "Workers AI now supports structured JSON outputs with sub-50ms latency...",
                prevText: "sk-proj-98a7bc12..."
            )

            popoverCard(
                caption: "2 · DENTRO DE INPUT (TRAVA ANTI-LOOP)",
                menuBarSymbol: "shield.lefthalf.filled",
                dotColor: Theme.amber,
                badge: "Input protegido",
                banner: "Cópia bloqueada em WhatsApp (AXTextArea) — seu clipboard foi preservado para colar com ⌘V.",
                bannerIcon: "shield.lefthalf.filled",
                bannerColor: Theme.amber,
                heroApp: "Google Chrome · blog.cloudflare.com",
                heroHasLink: true,
                heroText: "Workers AI now supports structured JSON outputs with sub-50ms latency...",
                prevText: "sk-proj-98a7bc12..."
            )

            popoverCard(
                caption: "3 · NO HERDR / TERMINAL (AUTO-PAUSE)",
                menuBarSymbol: "terminal",
                dotColor: Theme.blue,
                badge: "Passivo · Terminal",
                banner: "No Terminal o Markr fica 100% em pausa para não sobrepor a cópia nativa do Herdr.",
                bannerIcon: "terminal.fill",
                bannerColor: Theme.blue,
                heroApp: "Google Chrome · blog.cloudflare.com",
                heroHasLink: true,
                heroText: "Workers AI now supports structured JSON outputs with sub-50ms latency...",
                prevText: "sk-proj-98a7bc12..."
            )
        }
        .padding(28)
        .background(Theme.bg)
    }

    private func popoverCard(
        caption: String,
        menuBarSymbol: String,
        dotColor: Color,
        badge: String,
        banner: String?,
        bannerIcon: String,
        bannerColor: Color,
        heroApp: String,
        heroHasLink: Bool,
        heroText: String,
        prevText: String
    ) -> some View {
        VStack(spacing: 10) {
            Text(caption)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(Theme.muted)
                .tracking(0.6)

            // Menu bar strip
            HStack(spacing: 10) {
                Spacer()
                Image(systemName: "wifi").font(.system(size: 11))
                HStack(spacing: 4) {
                    Image(systemName: menuBarSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(dotColor)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(dotColor.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("Dom 01:42").font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Theme.body)
            .padding(.horizontal, 12)
            .frame(width: 330, height: 26)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 1))

            // Popover window
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Circle().fill(dotColor).frame(width: 8, height: 8)
                    Text("Markr").font(.system(size: 13.5, weight: .semibold)).foregroundColor(Theme.ink)
                    Text(badge)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(dotColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(dotColor.opacity(0.14))
                        .clipShape(Capsule())
                    Spacer()
                    Text("Ativo")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2.5)
                        .background(Theme.green.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface)

                Divider().overlay(Theme.hairline)

                if let banner = banner {
                    HStack(spacing: 7) {
                        Image(systemName: bannerIcon)
                            .font(.system(size: 11))
                            .foregroundColor(bannerColor)
                        Text(banner)
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.body)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(bannerColor.opacity(0.09))
                    Divider().overlay(Theme.hairline)
                }

                // Current clip card
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Image(systemName: "globe").font(.system(size: 11)).foregroundColor(Theme.blue)
                        Text(heroApp).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.muted)
                        if heroHasLink {
                            Image(systemName: "arrow.up.right.square").font(.system(size: 10.5)).foregroundColor(Theme.blue)
                        }
                        Spacer()
                        Text("✦ Auto").font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.green)
                    }

                    Text(heroText)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(Theme.ink)
                        .lineLimit(2)
                        .padding(7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.canvas)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.hairline, lineWidth: 1))

                    HStack {
                        Text("Anterior: \"\(prevText)\"")
                            .font(.system(size: 10.5))
                            .foregroundColor(Theme.muted)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 9.5, weight: .bold))
                            Text("Desfazer").font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(11)
                .background(Theme.card)

                Divider().overlay(Theme.hairline)

                // Recent 3 items preview
                VStack(spacing: 5) {
                    sampleRow(app: "Google Chrome · blog.cloudflare.com", text: "Workers AI now supports structured JSON...", time: "agora", active: true, hasLink: true)
                    sampleRow(app: "WhatsApp", text: "Fechado! Te mando o contrato atualizado até as 16h.", time: "3 min", active: false, hasLink: false)
                    sampleRow(app: "Safari · developer.apple.com", text: "AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute...", time: "12 min", active: false, hasLink: true)
                }
                .padding(9)
                .background(Theme.canvas)

                Divider().overlay(Theme.hairline)

                HStack {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 11))
                    Text("Abrir Histórico Completo e Busca").font(.system(size: 11.5, weight: .semibold))
                    Spacer()
                    Text("28 itens ↗").font(.system(size: 10.5)).foregroundColor(Theme.blue)
                }
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.surface)
            }
            .frame(width: 330)
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.hairline, lineWidth: 1))
        }
    }

    private func sampleRow(app: String, text: String, time: String, active: Bool, hasLink: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                if active {
                    Circle().fill(Theme.green).frame(width: 5.5, height: 5.5)
                }
                Text(app).font(.system(size: 10.5, weight: .semibold)).foregroundColor(Theme.body)
                if hasLink {
                    Image(systemName: "link").font(.system(size: 9.5)).foregroundColor(Theme.blue)
                }
                Spacer()
                Text(time).font(.system(size: 10)).foregroundColor(Theme.ash)
            }
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(active ? Theme.green.opacity(0.35) : Theme.hairline, lineWidth: 1)
        )
    }
}

// MARK: - 3. Full History Window View

struct HistoryWindowShowcaseView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Window Titlebar
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 11, height: 11)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 11, height: 11)
                    Circle().fill(Color(red: 0.15, green: 0.78, blue: 0.25)).frame(width: 11, height: 11)
                }
                Spacer()
                Text("Markr — Histórico Completo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                Spacer()
                Color.clear.frame(width: 48, height: 11)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.surface)

            // Search + Filter Chips
            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12.5)).foregroundColor(Theme.muted)
                    Text("Buscar por texto, aplicativo, janela ou URL...")
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.muted)
                    Spacer()
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.hairline, lineWidth: 1))

                HStack(spacing: 6) {
                    chip("Todos", selected: true)
                    chip("Google Chrome", selected: false)
                    chip("WhatsApp", selected: false)
                    chip("Safari", selected: false)
                    chip("Preview", selected: false)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 11)
            .background(Theme.surface)

            Divider().overlay(Theme.hairline)

            // Split View
            HStack(spacing: 0) {
                // Left list
                VStack(spacing: 6) {
                    leftItem(
                        app: "Google Chrome · blog.cloudflare.com",
                        text: "Workers AI now supports structured JSON outputs with sub-50ms latency...",
                        time: "agora",
                        selected: true,
                        active: true
                    )
                    leftItem(
                        app: "WhatsApp",
                        text: "Fechado! Te mando o contrato atualizado até as 16h no grupo.",
                        time: "3 min",
                        selected: false,
                        active: false
                    )
                    leftItem(
                        app: "Safari · developer.apple.com",
                        text: "AXUIElementCopyParameterizedAttributeValue(element, \"AXStringForTextMarkerRange\"...",
                        time: "12 min",
                        selected: false,
                        active: false
                    )
                    leftItem(
                        app: "Preview · arquitetura-v2.pdf",
                        text: "Seção 4.2 — Garantias de idempotência na camada de mensageria.",
                        time: "28 min",
                        selected: false,
                        active: false
                    )
                    Spacer()
                }
                .padding(10)
                .frame(width: 320)
                .background(Theme.canvas)

                Divider().overlay(Theme.hairline)

                // Right Detail Inspector
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text("Google Chrome")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.ink)
                                Text("✦ Auto")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(Theme.green)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.green.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            Text("08 de Novembro de 2026 às 01:42:19")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.muted)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc").font(.system(size: 11, weight: .bold))
                            Text("Copiar").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }

                    // Origin URL Card
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "macwindow").font(.system(size: 11)).foregroundColor(Theme.muted)
                            Text("Introducing Structured Outputs in Workers AI — Cloudflare Blog")
                                .font(.system(size: 11.5))
                                .foregroundColor(Theme.body)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "globe").font(.system(size: 11)).foregroundColor(Theme.blue)
                            Text("https://blog.cloudflare.com/structured-outputs-workers-ai/")
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundColor(Theme.blue)
                                .lineLimit(1)
                            Spacer()
                            Text("Abrir site ↗")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.blue)
                        }
                    }
                    .padding(10)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))

                    // Full text box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workers AI now supports structured JSON outputs with sub-50ms latency.\n\nBy constraining token generation directly at the inference engine level with a JSON Schema grammar, responses are guaranteed to match your application contract without retries or regex parsing.")
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundColor(Theme.ink)
                            .lineSpacing(3)
                        Spacer()
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.canvas)
            }
        }
        .frame(width: 820, height: 430)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
        .padding(20)
        .background(Theme.bg)
    }

    private func chip(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 11, weight: selected ? .semibold : .regular))
            .foregroundColor(selected ? .black : Theme.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(selected ? Color.white : Theme.card)
            .clipShape(Capsule())
    }

    private func leftItem(app: String, text: String, time: String, selected: Bool, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if active {
                    Circle().fill(Theme.green).frame(width: 6, height: 6)
                }
                Text(app).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.body).lineLimit(1)
                Spacer()
                Text(time).font(.system(size: 10.5)).foregroundColor(Theme.ash)
            }
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(Theme.ink)
                .lineLimit(2)
        }
        .padding(9)
        .background(selected ? Theme.cardHover : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selected ? Color.white.opacity(0.28) : Theme.hairline, lineWidth: 1)
        )
    }
}

Task { @MainActor in
    let assetsDir = "\(FileManager.default.currentDirectoryPath)/docs/assets"
    saveView(HeroBannerView(), to: "\(assetsDir)/hero-banner.png")
    saveView(PopoverShowcaseView(), to: "\(assetsDir)/popover-states.png")
    saveView(HistoryWindowShowcaseView(), to: "\(assetsDir)/history-window.png")
    exit(0)
}
RunLoop.main.run()
