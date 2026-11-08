# Markr — Handoff

> Como retomar este projeto amanhã (pessoa ou IA). Atualizado em **2026-11-08** · branch `main`

## Objetivo acordado

Utilitário nativo de barra de menus para macOS (**Markr** — *"marcou, copiou"*) na **Direção A — Cockpit Escuro (Raycast)** — v1.0 entregue e validada em uso real.

## Estado do ambiente

```text
Dir:      ~/markr
Branch:   main
Build:    ./scripts/build-app.sh -> ./build/Markr.app
```

## Cuidados para a próxima sessão

- Sempre recompilar via `./scripts/build-app.sh`: o script atualiza o binário *in-place* (sem `rm -rf` no bundle `.app`) e assina automaticamente com o certificado `Apple Development` do Keychain local quando disponível, mantendo a autorização em `Privacidade e Segurança > Acessibilidade` intacta entre recompilações.
- Histórico fica salvo localmente em `~/Library/Application Support/Markr/history.json` (fora do git) e preferências em `UserDefaults`.

## Próxima ação (checklist)

1. [x] F0 aprovado (Direção A — Cockpit Escuro)
2. [x] F1–F3 implementados, compilados e validados
3. [ ] (Opcional futuro) Implementar itens do backlog (`ROADMAP.md`) conforme necessidade no uso diário
