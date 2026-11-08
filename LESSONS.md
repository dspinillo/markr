# Markr — Lições

> Conhecimento que viaja com o repo: erros que custaram caro, padrões que funcionaram, armadilhas do ambiente.

## Armadilhas (o que quebrou)

- **Apps Chromium e Electron (Chrome, Arc, WhatsApp, Slack) retornam árvore AX vazia por padrão.** Por otimização de performance, o motor Blink só monta a árvore de Acessibilidade da página quando detecta um cliente AX ativo → **Contorno:** enviar `AXManualAccessibility = true` e `AXEnhancedUserInterface = true` para o `AXUIElementCreateApplication(pid)` assim que o app ganha foco (`didActivateApplicationNotification`) e no `leftMouseDown`, para que a seleção já esteja disponível no `leftMouseUp`.
- **Limite raso de subida (`kAXParentAttribute`) falha no WhatsApp e apps web modernos.** Em árvores DOM complexas, uma `<span>` (`AXStaticText`) de mensagem ou de um editor `contenteditable="true"` pode estar 15 a 30 níveis de `AXGroup` abaixo do `AXWebArea` ou `AXTextArea`. Subir apenas 8–10 níveis não alcança nem o `AXTextArea` (quebrando a trava de campo editável) nem o `AXWebArea` (onde fica o `AXSelectedTextMarkerRange`) → **Contorno:** subir até `depth < 40`, parando apenas ao atingir `AXWebArea`, `AXWindow` ou `AXApplication` (após checar `AXEditable` no próprio `AXWebArea` para cobrir editores baseados em `<iframe>`).
- **Coordenadas do `NSEvent.mouseLocation` vs `AXUIElementCopyElementAtPosition`.** O AppKit usa origem `(0, 0)` no canto **inferior esquerdo** da tela principal, enquanto o CoreGraphics/Accessibility usa origem `(0, 0)` no canto **superior esquerdo** → **Contorno:** usar `event.cgEvent?.location` (já em coordenadas Quartz) ou inverter o eixo Y (`primaryScreenHeight - nsPoint.y`).
- **Watcher passivo do `NSPasteboard` captura textos injetados por ferramentas de ditado por voz.** Apps de ditado (como Handy/Wispr) escrevem a transcrição no `NSPasteboard.general` antes de colar no app ativo; se o Markr observar mudanças externas do clipboard, cada frase ditada entra no histórico como se tivesse sido copiada da janela ativa → **Contorno:** gravar no `ClipHistory` exclusivamente o que o próprio `SelectionMonitor` capturar por seleção explícita do usuário.

## Padrões que funcionaram

- **Checar editabilidade tanto no `mouseDown` quanto no `mouseUp` (além do `focusedElement`).** Quando o usuário seleciona texto dentro de um `<input>` arrastando o cursor até fora da caixa de texto, o `mouseUp` pode cair num elemento estático vizinho. Guardar `wasEditableAtMouseDown` garante que a seleção iniciada dentro de um campo editável nunca dispare cópia automática.
- **Extração híbrida (`kAXSelectedTextAttribute` + `AXSelectedTextMarkerRange`) com limpeza de `\u{FFFC}`.** Enquanto apps nativos expõem `kAXSelectedTextAttribute` direto no elemento focado, o WebKit (Safari) e o Blink (Chrome/Electron) frequentemente expõem seleções que cruzam múltiplos parágrafos via `AXSelectedTextMarkerRange` + `AXStringForTextMarkerRange` no `AXWebArea` (incluindo o caractere Unicode `\u{FFFC}` quando há ícones/imagens no meio da seleção, que deve ser filtrado).

## Ambiente / ferramentas

- **Permissão TCC de Acessibilidade no macOS perde validade a cada build com assinatura ad-hoc (`--sign -`).** A assinatura ad-hoc grava o `cdhash` do binário como requisito de identidade no banco TCC do macOS; qualquer recompilação muda o hash e exige desligar/religar a chave em `Privacidade e Segurança > Acessibilidade` → **Contorno:** `scripts/build-app.sh` detecta automaticamente o certificado `Apple Development` no Keychain local e atualiza o binário *in-place* (sem `rm -rf` no `.app`), mantendo o *designated requirement* imutável entre builds.
