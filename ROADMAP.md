# Markr — Roadmap

> Atualizado em **2026-11-08**. Fonte de verdade do que ENTROU: [STATUS.md](STATUS.md).
> Legenda: ✅ feito · 🟡 parcial · ▶️ próximo · ⏸️ aguardando · 🔒 bloqueado · ⬜ não iniciado

## Já entregue (resumo)

- ✅ **F0 — Planejamento visual & direção de design:** scaffold N2 completo, plano visual em `docs/plano-visual.html` e **Direção A — Cockpit Escuro (Raycast)** aprovada em `decisions/0002-design.md`.
- ✅ **F1 — Motor de Seleção, Trava Anti-Editável & Auto-Pause no Terminal:** `SelectionMonitor`, `AccessibilityInspector`, `EditableGuard`, `TerminalAutoPause` e `ClipHistoryStore` validados em runtime.
- ✅ **F2 — Popover Cockpit Escuro & Janela de Histórico Completo:** `PopoverView` compacto (últimos 5 itens + "↩ Desfazer" + gaveta de preferências) e `HistoryWindowView` com busca, filtro por aplicativo e inspetor completo com URL clicável.
- ✅ **F3 — Ícone, Login Item & Empacotamento:** `AppIcon.icns` (Opção 01 — Grifo com Pinos), ícones de estado na Menu Bar, suporte a `SMAppService` (Iniciar no login) e `build/Markr.app` assinado.

## Marco atual

▶️ **v1.0 entregue e em uso** — acompanhar uso diário e colher melhorias para o backlog.

## Backlog (sem compromisso)

- ⬜ Tecla modificadora de override momentâneo (`Option` ao selecionar força cópia em campo editável ou ignora cópia em texto estático).
- ⬜ Fixar itens favoritos (Pin) no topo do `ClipHistory`.
- ⬜ Atalho global de teclado (ex.: `⌥⌘M`) para abrir o Popover ou a Janela de Histórico direto pelo teclado.
