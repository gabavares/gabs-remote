# Gabs Remote

Sistema próprio de acesso remoto: PC Windows do Gab (host) ↔ Galaxy Tab S10+ (app Android). Fork do Sunshine (host) + fork do moonlight-android (app), com módulos próprios (microfone, webcam, clipboard/arquivos, updater, conectividade remota).

- **Spec (fonte da verdade do design):** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md`
- **Planos de implementação:** `docs/superpowers/plans/` (um por fase)
- **Hospedagem do Gab:** `docs/resposta servidor.md` — Hostinger compartilhada, sem portas de entrada; não serve de relay.

## Como trabalhar aqui
- Idioma: tudo em pt-BR (docs, notas de versão, UI). Código e identificadores em inglês, seguindo o upstream.
- Nunca mexer no que já roda na hospedagem (site gabtavares.com, Vagabs, executor do Claude).
- Mudanças nos forks: pequenas, em módulos/pastas próprias, para facilitar merge do upstream.
- Publicar Release, criar repositório no GitHub ou dar push: só com o ok do Gab.
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>`.
- Segredos (keystore do APK, chave Ed25519 do manifesto, senhas) nunca entram no repositório.

## Sessões
- Cada fase = uma sessão para o plano e outra para a execução. Roteiro e prompts-modelo em `docs/sessoes.md`.
- Todo plano termina com "Próxima sessão" (prompt pronto). Ao fechar uma sessão, atualize `docs/sessoes.md` e diga ao Gab qual prompt usar.
- Não refaça o que está nos arquivos: a spec, os planos, `docs/decisoes/` e os checklists são a memória do projeto.

## graphify
Este projeto tem um grafo de conhecimento em `graphify-out/`.
- Antes de perguntas de arquitetura ou de "onde fica X", leia `graphify-out/GRAPH_REPORT.md` e use `/graphify query "<pergunta>"`.
- Depois de mudar arquivos de forma relevante (nova fase, forks adicionados), rode `/graphify . --update`.
