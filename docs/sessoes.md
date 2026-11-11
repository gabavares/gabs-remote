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
| 4. Atualização e CI | `plans/2026-11-09-fase-4-atualizacao-e-ci.md` (09/11/2026) | **Tasks 1–10 feitas (10/11/2026)**, Release 0.4.0. Task 11 Step 1 feito com as Releases **0.4.1 a 0.4.4 (cursor no tablet)**, PC e tablet na 0.4.4 e cursor aprovado pelo Gab (11/11/2026); resto da Task 11 (critério 7 com toques e tempos, testes da fase 3) **adiado** pelo Gab (11/11/2026) |
| 5. Áudio, mic, clipboard, arquivos | **próxima sessão: escrever o plano** | — |
| 6. Webcam | — | — |
| 7. Extras | — | — |
| 8. Cliente web | — | — |

## Próxima sessão (fase 5: escrever o plano)
Decisão do Gab (11/11/2026): as baterias de testes das fases 3 e 4 ficam **para depois**. Ele usou o sistema o dia inteiro em 10/11 (escritório, pelo Tailscale) e tudo o que existe até a 0.4.4 funcionou bem; prefere desenvolver as próximas funções antes. Os testes adiados estão na seção "Testes adiados (fases 3 e 4)" abaixo, com o prompt pronto, e não bloqueiam as fases seguintes.

> Gabs Remote — escrever o plano da **fase 5 (áudio, microfone, clipboard e arquivos)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (seções 6.3, 6.5, 10 e o critério 5, sem a câmera), `docs/decisoes/`, `docs/release.md` e `graphify-out/GRAPH_REPORT.md`; use o graphify para achar nos forks onde mexer. PC e tablet estão na 0.4.4; os testes pendentes das fases 3 e 4 foram adiados por decisão minha e não bloqueiam esta fase. Escreva com a skill writing-plans, com as entregas saindo em Releases pelo fluxo da decisão 0006, e termine com a seção "Próxima sessão".

## Testes adiados (fases 3 e 4)
Estado ao pausar (11/11/2026, depois da 0.4.4):
- **PC e tablet na 0.4.4**, cursor no tablet aprovado pelo Gab no escritório: mouse e trackpad do teclado com o ponteiro nativo do Android, formato seguindo o Windows; só a reação do Windows vem com o atraso da imagem.
- O host ficou na 0.4.0 até 11/11 porque o updater confere a cada 24 h (o Gab manteve 24 h); foi atualizado pelo painel. Para testar uma Release nova no mesmo dia: painel → "Procurar atualizações" e encerrar a sessão.
- O que sobrou de "elástico" é a latência da imagem pelo Tailscale: é o assunto da Task 9 da fase 3 e da medição no escritório.

Histórico do cursor (10/11/2026):
- **Release v0.4.1 publicada** às 12:11 (Task 11 Step 1): cursor desenhado no tablet. O host tira o cursor do vídeo com `grCursor=local` e conta o formato pelo `/gabs/cursor` (long poll); o app desenha o cursor (seta, texto, mão, redimensionar...) e manda a posição absoluta. Preferência "Cursor no tablet", ligada. Motivo: no escritório o mouse parecia atrasado porque o cursor vinha no vídeo (~40 ms). Host `86804db0`, app `97d26abe`, principal `b86761c`.
- A conferir na sessão de testes: o app e o host oferecerem a 0.4.1 sozinhos (toques e tempos em `docs/testes/fase-4-checklist.md`, seção da 0.4.1) e o cursor no uso real (formato, toque direto e caneta, rotação, velocidade 1:1 sem a aceleração do Windows). Se o Gab já anotou algo, está nessa seção.
- **0.4.2 (correção, mesmo dia):** na 0.4.1 o Gab viu a seta do app por cima do cursor do Windows (host ainda 0.4.0) e o mouse mais lento (sem a aceleração do Windows). A 0.4.2 só liga o cursor local depois que o host confirma pelo `/gabs/cursor` e aplica uma aceleração própria (`LocalCursor.gain`). Detalhes no checklist da fase 4.
- **0.4.3 (correção, mesmo dia):** a aceleração da 0.4.2 ficou rápida demais e fazia o cursor pular (ganho calculado pela hora do processamento, com eventos em lote). A 0.4.3 tira a aceleração: o cursor anda na tela o mesmo que o dedo, e a velocidade fica em Configurações → "Velocidade do cursor" (`gr_cursor_speed`).
- **0.4.4 (mesmo dia):** o mouse e o trackpad do teclado passam a usar o ponteiro nativo do Android (sem captura, ícone por `PointerIcon` conforme o formato do Windows), igual ao de fora do app. O trackpad na tela segue com o cursor desenhado pelo app. Se a rolagem de dois dedos vier invertida, trocar o sinal em `NativePointer.SwipeScroll`.
- Não testado ao vivo antes da Release (o Gab estava usando o PC pelo Tailscale): a rota `/gabs/cursor` só tem os testes unitários do tracker.

Estado anterior (10/11/2026, 0.4.0):
- Tasks 1–10 feitas. Release **v0.4.0 publicada** (github.com/gabavares/gabs-remote/releases/tag/v0.4.0), com instalador, APK assinado e manifesto assinado. PC com o host 0.4.0 da Release (painel "Em dia"); tablet com o app 0.4.0 (4000).
- Como fazer uma Release: `docs/release.md` (o `preparar-release.ps1` roda com `-ExecutionPolicy Bypass`). CI: `.github/workflows/testes.yml` (verde) e `release.yml`.
- Revisão final: 4 achados importantes corrigidos; os menores ficaram no ledger `.superpowers/sdd/2026-11-09-fase-4-atualizacao-e-ci/progress.md` (linhas `Final: minor (deferred)`). Os mais visíveis: a atualização do app ainda pede um toque; os atalhos da tela inicial não passam pelo aviso de compatibilidade; o painel diz "sessão ativa" quando o motivo é o PC pronto.
- Observação do Gab: no 4G roteado pelo celular, pelo Tailscale, mais de 60 fps e menos de 40 ms.
- Pendências do Gab fora do código: refazer o `.7z` de backup com a keystore **e** a chave do manifesto (`docs/segredos.md`) e trocar as cópias do Drive e do pendrive.
- Plano da fase 5: há um cartão de sessão proposto (só escrever o plano); a ordem combinada é depois da Task 11.

A sessão de testes em lote (fase 3 + fase 4) usa:

> Gabs Remote — sessão de testes em lote: resto da Task 11 do plano `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md` (PC e tablet já na 0.4.4, cursor no tablet aprovado; falta o critério 7 com toques e tempos numa Release nova, que pode ser a próxima de verdade) junto do roteiro pendente em `docs/testes/fase-3-checklist.md`: medição no escritório (caminho do Tailscale direto ou DERP, medidor de clique e carimbo), WoL de fora e a Task 9 da fase 3 (latência ≤ 30 ms, um ajuste por vez). O foco é a latência da imagem: o ponteiro já é o do tablet e o que sobra é a reação do Windows. Leia o `CLAUDE.md`, os dois checklists, `docs/latencia.md` e `docs/release.md`. Eu trago os números do escritório. Commit, push, tag e Release sem pedir. No fim, feche os checklists das fases 3 e 4, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt do plano da fase 5.

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
