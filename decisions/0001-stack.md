# 0001 - Stack e arquitetura inicial

Data: 2026-11-08

## Contexto

O Markr precisa observar seleções de texto feitas com o mouse em qualquer aplicativo do macOS (navegadores, WhatsApp, PDFs, apps nativos), verificar em poucos milissegundos se o elemento selecionado é editável ou apenas leitura, e copiar o texto para o clipboard sem interferir nos atalhos ou na fluidez do cursor. Restrições principais: consumo mínimo de CPU/RAM (app residente na barra de menus o dia inteiro), acesso direto às APIs nativas de Acessibilidade do macOS (`AXUIElement`) e zero dependências externas.

## Decisão

- **Swift 6 + AppKit / SwiftUI:** `NSStatusItem` + `NSPopover` em SwiftUI para a interface de barra de menus, sem ícone no Dock (`LSUIElement = true`).
- **Monitoramento de eventos:** `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])` em modo passivo (listen-only), evitando `CGEventTap` ativo que possa atrasar o cursor do sistema caso um app demore a responder.
- **Inspeção e captura:** `ApplicationServices` (`AXUIElement`) combinando leitura de `kAXSelectedTextAttribute` e `AXSelectedTextMarkerRange` (`AXStringForTextMarkerRange`), com warm-up automático de `AXManualAccessibility` / `AXEnhancedUserInterface` para suporte nativo a Chromium/Electron e WebKit.
- **Trava anti-loop (`EditableGuard`):** verificação em 3 pontos (`focusedElement`, `mouseDownPoint`, `mouseUpPoint`) e subida de até 40 níveis na árvore de pais (`kAXParentAttribute`) checando `AXEditable`, `AXTextField`, `AXTextArea`, `AXSearchField`, `AXComboBox` e `kAXValueAttribute` gravável.
- **Persistência:** `UserDefaults` para preferências e `~/Library/Application Support/Markr/history.json` para o histórico de clips.
- **Empacotamento:** Swift Package Manager + script `./scripts/build-app.sh` gerando `./build/Markr.app` assinado.

## Consequências

- + Binário nativo minúsculo, impacto zero na bateria e acesso de primeira classe à API `AXUIElement`.
- + O monitor passivo (`addGlobalMonitorForEvents`) garante que o cursor do macOS nunca engasgue, mesmo se um aplicativo alvo travar.
- − Exige que o usuário conceda permissão de Acessibilidade (`Privacidade e Segurança > Acessibilidade`) na primeira execução.
