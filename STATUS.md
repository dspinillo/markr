# Markr — Status

> Atualize ao final de cada sessão. Última atualização: **2026-11-08** · frente ativa: Concluído (v1.0 em uso)
> Legenda: ✅ feito · 🟡 parcial · ▶️ próximo · ⏸️ aguardando · 🔒 bloqueado · ⬜ não iniciado

## Estado atual (leia primeiro)

**F0, F1, F2 e F3 concluídos e validados em uso real.** O `Markr.app` roda na barra de menus do macOS:
- Copia automaticamente ao selecionar texto (arraste ou duplo/triplo clique) fora de terminais.
- Muda o ícone para escudo (`shield.lefthalf.filled`) e bloqueia a cópia quando a seleção ocorre dentro de um campo de edição (`EditableGuard`), preservando o clipboard para `Cmd + V`.
- Muda o ícone para terminal (`>_`) e entra em pausa automática (`TerminalAutoPause`) quando o foco está em um terminal para não sobrepor a cópia nativa.
- Exibe o Popover compacto na **Direção A — Cockpit Escuro (Raycast)** com os últimos 5 clips, botão "↩ Desfazer", origem de cada clip (nome/ícone do app + URL/domínio clicável) e janela dedicada **"Markr — Histórico Completo"** para busca e inspeção de até 300 itens.

| Bloco | Estado |
|---|---|
| F0 — planejamento visual + direção A (`decisions/0002-design.md`) | ✅ |
| F1 — motor de seleção, trava anti-editável & auto-pause no terminal | ✅ |
| F2 — popover Cockpit Escuro + janela de histórico completo com origem App/URL | ✅ |
| F3 — ícone `AppIcon.icns`, login item & empacotamento `build/Markr.app` | ✅ |

## Onde paramos (última sessão)

- **Feito:** ciclo completo F0 → F3 entregue: scaffold N2, `docs/plano-visual.html`, `decisions/0002-design.md` (Direção A), código completo em `Sources/Markr/`, janela de histórico completo (`HistoryWindow.swift`), geração de ícone (`Resources/AppIcon.icns`) e empacotamento assinado em `build/Markr.app`.
- **Validado:** testado em runtime — cópia automática, troca de ícone e bloqueio em campos editáveis, auto-pause no terminal, imutabilidade da ordem/data do histórico ao recopiar e persistência da permissão TCC entre builds.
- **Pendente:** nada bloqueante; ideias de evolução registradas no backlog do `ROADMAP.md`.
- **Próxima ação:** ▶️ acompanhar uso diário e evoluir itens do backlog conforme necessidade.

## Histórico de sessões

<details>
<summary>Sessão 2026-11-08 — Kickoff, F0 (Direção A) e entrega completa v1.0 (F1–F3)</summary>

Implementação completa do Markr: motor AX com warm-up para Chromium/Electron, trava para campos editáveis, auto-pause em terminais, Popover compacto + janela de histórico completo com captura de URL e ícone nativo.

</details>
