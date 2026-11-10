# Roteiro de sessões do Claude

Cada fase usa **duas sessões novas**: uma para escrever o plano, outra para executá-lo. Isso mantém o contexto limpo e evita gastar tokens relendo conversa antiga. Tudo o que importa fica nos arquivos (spec, planos, decisões, checklists, grafo), nunca só na conversa.

Regra: **todo plano termina com a seção "Próxima sessão"**, com o prompt pronto. Ao fim de cada sessão, o Claude diz qual prompt usar.

## Onde estamos
| Fase | Plano | Execução |
|---|---|---|
| 0. Design | spec aprovada (06/11/2026) | — |
| 1. Ambiente e forks | `plans/2026-11-06-fase-1-ambiente-e-forks.md` | **feita (07/11/2026)**: host e app compilam, linha de base em `docs/testes/fase-1-checklist.md` |
| 2. Streaming (casa e fora via Tailscale) | `plans/2026-11-07-fase-2-streaming.md` (07/11/2026) | **feita (07/11/2026)**: critérios 2–4 e 6 atendidos, sessão no 4G pelo Tailscale; checklist em `docs/testes/fase-2-checklist.md` |
| 3. Fora de casa completo | `plans/2026-11-07-fase-3-fora-de-casa.md` (07/11/2026) | **código feito (09/11/2026)**: Tasks 1–8, host e APK instalados; faltam as verificações no escritório e as Tasks 9–10 (`docs/testes/fase-3-checklist.md`) |
| 4. Atualização e CI | — | — |
| 5. Áudio, mic, clipboard, arquivos | — | — |
| 6. Webcam | — | — |
| 7. Extras | — | — |
| 8. Cliente web | — | — |

## Próxima sessão (fase 4, plano)
O Gab decidiu (09/11/2026) seguir para a fase 4 e testar em lote depois: as verificações de campo da fase 3 (roteiro em `docs/testes/fase-3-checklist.md`) ficam para uma sessão de testes junto com as da fase 4.

> Gabs Remote — escrever o plano da **fase 4 (Atualização e CI)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§8 Atualização automática, §9.1, §10 linha da fase 4), `docs/decisoes/` (a 0002 trava o `applicationId`; a 0005 diz que nada do host fica aberto para a internet), `docs/segredos.md`, `docs/testes/fase-3-checklist.md` (o que ficou para testar em lote) e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks o build, a versão e o painel do host. A fase 3 tem verificações de campo pendentes: o plano termina com uma task de testes em lote (fase 3 + fase 4). Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

Para fechar só a fase 3 (testes do escritório e Task 9), se preferir antes da fase 4:

> Gabs Remote — continuar a fase 3 (`docs/superpowers/plans/2026-11-07-fase-3-fora-de-casa.md`): as Tasks 1–8 estão feitas; falta a Task 9 (latência em casa) e a Task 10 (medição no escritório, checklist e fechamento). Leia o `CLAUDE.md`, a decisão 0005, `docs/testes/fase-3-checklist.md` e o ledger `.superpowers/sdd/2026-11-07-fase-3-fora-de-casa/progress.md`. Execução nativa (executing-plans), pedindo meu ok nos passos marcados (serviço, firewall, push). Trago os números do escritório. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

Estado ao pausar a fase 3 (09/11/2026):
- Código das Tasks 1–8 feito, mais o IPv4 de casa por STUN (`ExternalIP`): host `f02a71f3`, app `43c20bbf`. Host instalado no serviço `GabsRemote` (STUN conferido no log); APK de release no tablet. **Enviado ao GitHub em 09/11/2026** (host, app e principal), com o ok do Gab.
- Decisão 0005: fora de casa só pelo Tailscale (nenhuma porta aberta; IPv6 de entrada barrado no roteador); WoL de fora pelo roteador (UDP 8080 → PC, IP do PC reservado no DHCP); sem 2º fator e sem bloqueio ao desconectar.
- Verificado em casa: 0 erros `WSASendMsg` (eram 10022 e depois 10014), MAC e endereço de casa certos pelo Tailscale, "Conectado por Rede de casa".
- Uso real do Gab: tablet no Wi-Fi do escritório, PC pelo Tailscale; ele quase não usa o tablet em casa (a troca casa ↔ fora não é testada).
- Presença na hospedagem **não publicada** (o `rsync --delete` do deploy do site apagaria a pasta); código em `web/presenca/`. O WoL de fora usa o IP de casa que o host descobre por STUN e o app guarda ao ver o PC; só falha se o IP da Vivo mudar com o PC desligado.
- Pendências fora do código: prova do backup da keystore em `docs/segredos.md`; minors adiados nos ledgers das fases 2 e 3.

Decisões do Gab ao planejar a fase 3 (07/11/2026): sem 2º fator e sem bloqueio do PC ao desconectar; a reconexão automática não muda a decisão 0004.

Estado ao fechar a fase 2 (07/11/2026):
- Host como serviço `GabsRemote` e APK de release instalados, na versão atual (host `eaa0d85a`, app `d666d2cb`). Host, app e principal enviados ao GitHub em 07/11/2026, com o ok do Gab.
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
