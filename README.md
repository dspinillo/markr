# Markr

> **Marcou, copiou** — utilitário nativo de barra de menus para macOS que copia automaticamente qualquer texto selecionado (arraste ou duplo/triplo clique) com trava inteligente contra campos editáveis, auto-pause no terminal e histórico com origem.
>
> **Tipo:** `desktop` · **Nível:** `N2` · **Stack:** Swift 6 / SwiftUI + AppKit (`NSStatusItem` + `NSPopover`) + `ApplicationServices` (`AXUIElement`)
> **Estado:** [STATUS.md](STATUS.md) · **Por quê:** [decisions/](decisions/) · **Plano visual (F0):** [docs/plano-visual.html](docs/plano-visual.html)

## Visão

Quem usa emuladores de terminal modernos (Herdr, iTerm2, Ghostty, Warp) acostuma rápido com o comportamento de **Copy on Select**: selecionou um trecho na tela, ele já está na área de transferência — sem precisar apertar `Cmd + C`. Fora do terminal, porém, o macOS exige o atalho manual em toda seleção de navegador, WhatsApp, PDF ou documentação.

O **Markr** leva essa fluidez para o macOS inteiro, resolvendo os três problemas práticos de extensões genéricas de *auto-copy*:

1. **Trava Anti-Editável (`EditableGuard`):** quando você quer colar um texto por cima de outro dentro de um `<input>`, `<textarea>`, caixa de mensagem do WhatsApp (`contenteditable`) ou editor de código, você seleciona o texto antigo para substituí-lo com `Cmd + V`. O Markr inspeciona a árvore de Acessibilidade (`AXUIElement`) em até 40 níveis antes de agir e **bloqueia a cópia automática** quando a seleção ocorre dentro de um campo editável (mudando o ícone da Menu Bar para um escudo `🛡`).
2. **Auto-Pause em Terminais (`TerminalAutoPause`):** quando o foco está no `Terminal.app` / `Herdr`, `iTerm2`, `Warp`, `Ghostty`, `Kitty` ou `Alacritty`, o Markr entra em pausa automática (ícone `>_` na Menu Bar) para nunca sobrepor ou conflitar com o *copy-on-select* nativo do terminal.
3. **Histórico com Origem (`ClipHistory` + `ClipOrigin`):** guarda os textos copiados exibindo de onde cada trecho veio — ícone e nome do aplicativo (`WhatsApp`, `Preview`) e, quando copiado de um navegador (`Chrome`, `Safari`, `Arc`, `Brave`), a **URL/domínio clicável** da página original extraída via `AXURL` / `AXDocument`.

## Mapa do projeto

```text
markr/
├── README.md        # visão + como compilar e rodar
├── STATUS.md        # estado atual e histórico de sessões
├── HANDOFF.md       # guia rápido de retomada
├── ROADMAP.md       # fases entregues e backlog
├── CONTEXT.md       # vocabulário ubíquo do domínio
├── LESSONS.md       # aprendizados e armadilhas de AX/TCC no macOS
├── decisions/       # ADRs (0001-stack.md, 0002-design.md)
├── docs/            # plano-visual.html e icones.html
├── Resources/       # AppIcon.icns
├── scripts/         # build-app.sh e generate-icon.swift
└── Sources/Markr/   # código-fonte Swift/SwiftUI
```

## Como compilar e rodar

Requer macOS 13+ e Swift 5.9+ (Xcode Command Line Tools).

```bash
./scripts/build-app.sh
open ./build/Markr.app
```

Na primeira execução, ative a permissão do **Markr** em `Ajustes do Sistema > Privacidade e Segurança > Acessibilidade`.

## Licença

Distribuído sob a licença [MIT](LICENSE).
