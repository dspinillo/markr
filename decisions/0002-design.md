# 0002 - Direção visual A (Cockpit Escuro) + Histórico com Origem e Auto-Pause no Terminal

Data: 2026-11-08

## Contexto

No fechamento do F0 (`docs/plano-visual.html`), avaliamos três direções para o Popover da barra de menus do Markr:
- **A — Cockpit Escuro** (estilo Raycast)
- **B — Precisão Técnica** (estilo Linear)
- **C — Papel Editorial** (estilo Claude)

Além da escolha visual, definimos três pilares de produto:
1. **Histórico cronológico imutável (`ClipHistory`):** guardar os itens copiados pelo Markr (exibindo os 5 últimos no Popover compacto e até 300 na janela dedicada "Histórico Completo"), mantendo ordem e data originais mesmo ao recopiar um item antigo.
2. **Captura de origem (`ClipOrigin`):** registrar de onde cada texto foi copiado — se veio de um navegador (Chrome, Safari, Arc, Brave), capturar a **URL/domínio** do site via `AXURL` / `AXDocument`; se veio de um app (WhatsApp, PDF no Preview), capturar o **nome do app** e título da janela/documento.
3. **Auto-Pause em Terminais (`TerminalAutoPause`):** desligar automaticamente o gatilho de seleção do Markr quando o foco estiver no terminal (`Terminal.app` / `Herdr`, `iTerm2`, `Warp`, `Ghostty`, `Kitty`, `Alacritty`), evitando sobrepor ou conflitar com o *copy-on-select* nativo do terminal.

## Decisão

- **Direção visual escolhida: A — Cockpit Escuro:**
  - Canvas quase-preto (`#07080a`) com escada de superfície sutil (`#0d0d0d` no cabeçalho/rodapé, `#101111` nos cards de histórico e `#171819` no item selecionado).
  - Bordas hairline de `1px` em `#242728`.
  - Indicadores semânticos pontuais: verde `#59d499` (Ativo / AutoClip), azul `#57c1ff` (Modo Passivo no Terminal / Origem URL), âmbar `#ffc533` (`EditableGuard` acionada).
  - Botão de ação rápida ("↩ Desfazer" / "Copiar") em pastilha branca de alto contraste (`#ffffff` com texto `#000000`).
- **Ícone do Aplicativo (`AppIcon.icns`):**
  - Opção 01 — Grifo com Pinos (linha central destacada em verde-esmeralda `#59d499` com os dois pinos brancos de seleção), mantendo na Menu Bar os ícones nativos dinâmicos (`doc.on.clipboard`, `checkmark.circle.fill`, `shield.lefthalf.filled`, `terminal`, `pause.rectangle`).

## Consequências

- + Zero conflito com o *copy-on-select* nativo de terminais e com ferramentas de ditado por voz.
- + Rastreabilidade imediata ("de onde tirei essa frase?") com link clicável quando a origem for web.
- + Popover enxuto na barra de menus + janela completa sob demanda para buscas longas.
