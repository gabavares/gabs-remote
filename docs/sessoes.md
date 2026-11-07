# Roteiro de sessões do Claude

Cada fase usa **duas sessões novas**: uma para escrever o plano, outra para executá-lo. Isso mantém o contexto limpo e evita gastar tokens relendo conversa antiga. Tudo o que importa fica nos arquivos (spec, planos, decisões, checklists, grafo), nunca só na conversa.

Regra: **todo plano termina com a seção "Próxima sessão"**, com o prompt pronto. Ao fim de cada sessão, o Claude diz qual prompt usar.

## Onde estamos
| Fase | Plano | Execução |
|---|---|---|
| 0. Design | spec aprovada (06/11/2026) | — |
| 1. Ambiente e forks | `plans/2026-11-06-fase-1-ambiente-e-forks.md` | **feita (07/11/2026)**: host e app compilam, linha de base em `docs/testes/fase-1-checklist.md` |
| 2. Streaming (casa e fora via Tailscale) | `plans/2026-11-07-fase-2-streaming.md` (07/11/2026) | **feita (07/11/2026)**: critérios 2–4 e 6 atendidos, sessão no 4G pelo Tailscale; checklist em `docs/testes/fase-2-checklist.md` |
| 3. Fora de casa completo | — | — |
| 4. Atualização e CI | — | — |
| 5. Áudio, mic, clipboard, arquivos | — | — |
| 6. Webcam | — | — |
| 7. Extras | — | — |
| 8. Cliente web | — | — |

## Próxima sessão (fase 3, plano)
> Gabs Remote — escrever o plano da **fase 3 (Fora de casa completo)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§5 Rede e conexão, §7 Disponibilidade, §10 linha da fase 3, §11 Riscos), `docs/decisoes/` (a 0004 explica o PC pronto em segundo plano), `docs/testes/fase-2-checklist.md` (linha de base e observações para a fase 3), `docs/tailscale.md`, `docs/resposta servidor.md` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks onde mexer. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

Estado ao fechar a fase 2 (07/11/2026):
- Host como serviço `GabsRemote` e APK de release instalados, na versão atual (host `eaa0d85a`, app `d666d2cb`). Nada foi enviado ao GitHub: push dos submódulos e do principal só com o ok do Gab.
- Linha de base: em casa a 120 fps, clique até a imagem 32 ms em média (p95 39 ms; meta do critério 1: ≤ 30 ms) e carimbo 28,7 ms; a 60 fps o carimbo sobe para 50 ms (decodificador da MediaTek mais lento com menos quadros). Fora de casa: Tailscale funcionando, sem números (o 4G do Gab limitou; ele usa o Wi-Fi do escritório).
- Pontos para o plano da fase 3:
  - Medir o critério 1 fora de casa (Wi-Fi do escritório), com o caminho do Tailscale (direto ou DERP) registrado; o caminho no 4G não foi registrado.
  - `WSASendMsg() failed: 10022` às centenas no início das sessões (casa e Tailscale, a 90 e 120 fps): investigar no envio de vídeo do host.
  - `Unable to find MAC address for 100.99.120.91` a cada 1,5 s com o app na lista de PCs pelo Tailscale: relevante para o WoL de fora.
  - Reconexão na troca de rede (Wi-Fi ↔ 4G) e o PC pronto sem tempo limite (decisão 0004): se a reconexão automática mudar isso, perguntar ao Gab.
  - Se a tela virtual sumir com o host rodando (reinício do driver), o registro em memória fica preso até reiniciar o serviço (raro; documentado no checklist).
- Pendências fora do código: prova do backup da keystore (hash do `.jks` baixado do Drive) em `docs/segredos.md`; minors adiados no ledger `.superpowers/sdd/2026-11-07-fase-2-streaming/progress.md` (entre eles: host que cai no meio da sessão deixa o teclado pt-BR no PC).
- Problemas conhecidos e saídas: se as sessões derem `DevicePrepFailed` sem motivo, apagar `C:\Program Files\Gabs Remote\config\display_device.state` com o serviço parado; se o teclado ficar em português depois de usar outro app, o PC ainda está "pronto": entrar na sessão e Desconectar.

## Prompts-modelo

**Escrever o plano da fase N:**
> Gabs Remote — escrever o plano da **fase N (nome)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (seções da fase), `docs/decisoes/`, o checklist da fase anterior em `docs/testes/` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks onde mexer. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

**Executar o plano da fase N:**
> Gabs Remote — executar o plano `docs/superpowers/plans/<arquivo>.md`. Leia o `CLAUDE.md` e o plano. Execução nativa (executing-plans), pedindo meu ok nos passos marcados. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

**Retomar uma execução interrompida:**
> Gabs Remote — continuar a execução de `docs/superpowers/plans/<arquivo>.md`. Confira no `git log` e nos checkboxes o que já foi feito e siga da próxima tarefa.
