# Markr — Contexto (linguagem ubíqua)

> O vocabulário do projeto: os termos do domínio que o código, os docs e as conversas usam — com a definição de cada um. Serve pra naming consistente e pra não re-explicar termo a cada sessão/agente.

## Termos do domínio

| Termo | Significa | No código |
|---|---|---|
| Markr | O utilitário de barra de menus; toda referência ao app usa "o Markr" | target/app `Markr` |
| `MarkGesture` | Gesto físico do mouse que caracteriza intenção de marcar texto: arraste (`drag >= 6pt`), duplo/triplo clique (`clickCount >= 2`) ou `Shift + Clique` | `SelectionMonitor` |
| `EditableGuard` | A trava que inspeciona se a seleção ocorreu dentro de um controle editável (`AXTextField`, `AXTextArea`, `AXEditable`, `contenteditable`) e bloqueia a cópia automática | `isElementOrAncestorsEditable` |
| `AXWarmup` | Ativação proativa dos atributos `AXManualAccessibility` e `AXEnhancedUserInterface` no `pid` de apps Chromium/Electron para que a árvore DOM/AX exista antes do `mouseUp` | `warmUpApplicationIfNeeded(pid:)` |
| `AutoClip` | Uma captura realizada automaticamente pelo Markr após um `MarkGesture` aprovado pela `EditableGuard` | `ClipTrigger.autoSelect` |
| `ClipHistory` | Lista cronológica e imutável dos itens copiados pelo Markr, persistida localmente | `ClipHistoryStore` / `[ClipItem]` |
| `ClipOrigin` | Metadados de onde o texto foi copiado: nome do app (`WhatsApp`, `Google Chrome`), título da janela e `sourceURL` (domínio + URL completa quando copiado de navegador) | `ClipOrigin` |
| `TerminalAutoPause` | Modo em que o Markr detecta que o app em foco é um terminal (`Terminal.app` / `Herdr`, `iTerm2`, `Warp`, `Ghostty`, `Kitty`, `Alacritty`) e entra em pausa automática para não sobrepor a cópia nativa do terminal | `isTerminalApp` |
| `PreviousClip` | O item ativo imediatamente anterior no `ClipHistory`, restaurável em 1 clique pelo botão "↩ Desfazer" sem alterar a ordem cronológica da lista | `restorePreviousClip()` |

## Não confundir

- **`EditableGuard` ≠ `IgnoredApp`** — `IgnoredApp` desliga o gatilho de seleção no aplicativo inteiro; `EditableGuard` atua dentro de qualquer app ativo, diferenciando uma mensagem recebida no WhatsApp (copia) da caixa de digitação de mensagem do WhatsApp (bloqueia).
- **Recopiar do histórico ≠ nova captura** — clicar num item antigo do `ClipHistory` coloca seu texto de volta no clipboard e acende o indicador de item ativo, mas preserva a posição e a data/hora originais na linha do tempo.
