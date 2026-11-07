# Roteiro de sessões do Claude

Cada fase usa **duas sessões novas**: uma para escrever o plano, outra para executá-lo. Isso mantém o contexto limpo e evita gastar tokens relendo conversa antiga. Tudo o que importa fica nos arquivos (spec, planos, decisões, checklists, grafo), nunca só na conversa.

Regra: **todo plano termina com a seção "Próxima sessão"**, com o prompt pronto. Ao fim de cada sessão, o Claude diz qual prompt usar.

## Onde estamos
| Fase | Plano | Execução |
|---|---|---|
| 0. Design | spec aprovada (06/11/2026) | — |
| 1. Ambiente e forks | `plans/2026-11-06-fase-1-ambiente-e-forks.md` | **feita (07/11/2026)**: host e app compilam, linha de base em `docs/testes/fase-1-checklist.md` |
| 2. Streaming (casa e fora via Tailscale) | `plans/2026-11-07-fase-2-streaming.md` (07/11/2026) | **em andamento (07/11/2026)**: código das Tasks 1–7 e 9 pronto, testado e revisado; serviço instalado; faltam os testes no tablet (Tasks 2, 4–9), o Tailscale (Task 10) e o fechamento (Task 11) |
| 3. Fora de casa completo | — | — |
| 4. Atualização e CI | — | — |
| 5. Áudio, mic, clipboard, arquivos | — | — |
| 6. Webcam | — | — |
| 7. Extras | — | — |
| 8. Cliente web | — | — |

## Próxima sessão (fase 2, continuação)
> Gabs Remote — continuar a execução de `docs/superpowers/plans/2026-11-07-fase-2-streaming.md`. Leia o `CLAUDE.md`, o ledger `.superpowers/sdd/2026-11-07-fase-2-streaming/progress.md` (o que já foi feito, rulings e minors adiados) e `git log` do principal e dos submódulos. Comece pelos problemas abertos listados abaixo (menu de três dedos, trackpad rotacionado, layout pt-BR), com teste antes de cada correção; depois siga pelos testes no tablet: Tasks 2 (Step 8), 4 (Step 4), 5–7 (verificações restantes: perfis 67/50/1080/720, Espelhar, driver desabilitado), 8 (matriz em `docs/testes/fase-2-entrada.md`), 9 (Step 5), 10 e 11. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da fase 3.

Estado em 07/11/2026 (sessão de execução):
- Driver de tela virtual: **SudoVDA 1.10.9.289** (decisão 0003), instalado; o certificado da SudoMaker foi aceito pelo Gab.
- Keystore de release criada, com backup no Drive e no pendrive; falta a prova do backup (hash do `.jks` extraído do Drive) em `docs/segredos.md`.
- Serviço `GabsRemote` instalado em `C:\Program Files\Gabs Remote` (build das 13:20, com escala do Windows e `grKeyboard`).
- Revisão final feita (1 crítico e 6 importantes corrigidos com teste); 9 minors adiados no ledger.
- Testado no tablet (07/11, 03:09): Nativo 2800×1752 a **120 fps**, escala do Windows 150% (pedido do Gab, já implementado: preferência "Escala do Windows na tela virtual"), monitores físicos voltam ao desconectar, caneta funcionando. Host e APK instalados são os da versão atual.
- **Problemas da sessão anterior resolvidos e testados no tablet (07/11, 13:25):** (1) o menu de três dedos abria fora da tela (o PopupMenu descia da tela da sessão, que ocupa tudo); agora abre no ponto do toque; (2) trackpad do Book Cover na direção certa; (3) teclado pt-BR (`grKeyboard`, padrão ABNT2): o host pede o layout de novo por 10 s, porque a troca de tela tira o foco da janela; o PC volta ao inglês ao desconectar. Host e APK instalados são os da versão atual.
- **Pedidos do Gab testados no tablet (07/11, 14:25):** trackpad do Book Cover com gestos (dois dedos rolam, toques clicam, arrastar com o botão físico); app em segundo plano mantém o PC pronto (tela virtual e teclado) e só Voltar ou Desconectar liberam o PC (decisão do Gab: sem tempo limite; se o app for fechado à força, encerrar o app no painel do host libera); teclado pt-BR também depois do login e do Win+L. Task 2 Step 8 e Task 4 Step 4 conferidos (nome e pacote do APK, tela de login, UAC, `AUTO_START`, reinício em até 5 s); o Moonlight (Debug) já não estava no tablet. Perfis 67/50/1080/720 e Espelhar conferidos (barras pretas no Fixo aceitas); corrigido o padrão do teclado gravado como "10416". Driver desativado conferido (cai no espelhamento do TCL). Corrigido o registro de telas que guardava a tela virtual (reversões falhando depois da reinstalação); se um dia as sessões derem `DevicePrepFailed` sem motivo, apagar `C:\Program Files\Gabs Remote\config\display_device.state` com o serviço parado.

Roteiro do próximo teste no tablet, nesta ordem (depuração USB ligada, tablet no cabo, para ler o log): fechamento (Task 11: medições a 60/90/120 fps e Espelhar com a tela em movimento, checklist final, spec).

## Prompts-modelo

**Escrever o plano da fase N:**
> Gabs Remote — escrever o plano da **fase N (nome)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (seções da fase), `docs/decisoes/`, o checklist da fase anterior em `docs/testes/` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks onde mexer. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

**Executar o plano da fase N:**
> Gabs Remote — executar o plano `docs/superpowers/plans/<arquivo>.md`. Leia o `CLAUDE.md` e o plano. Execução nativa (executing-plans), pedindo meu ok nos passos marcados. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

**Retomar uma execução interrompida:**
> Gabs Remote — continuar a execução de `docs/superpowers/plans/<arquivo>.md`. Confira no `git log` e nos checkboxes o que já foi feito e siga da próxima tarefa.
