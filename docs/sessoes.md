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
- Serviço `GabsRemote` instalado em `C:\Program Files\Gabs Remote`, mas **com o build anterior às correções da revisão**: rodar de novo `instalar-host.ps1` como administrador antes de testar.
- Revisão final feita (1 crítico e 6 importantes corrigidos com teste); 9 minors adiados no ledger.
- Testado no tablet (07/11, 03:09): Nativo 2800×1752 a **120 fps**, escala do Windows 150% (pedido do Gab, já implementado: preferência "Escala do Windows na tela virtual"), monitores físicos voltam ao desconectar, caneta funcionando. Host e APK instalados são os da versão atual.
- **Problemas abertos:** (1) o toque de três dedos não abre o menu da sessão; investigar com `adb logcat` (o Gab liga a depuração USB); (2) o trackpad do teclado físico do tablet (Book Cover) chega rotacionado 90° (arrastar para a esquerda sobe o cursor, para baixo vai à esquerda); (3) pedido novo: trocar o layout de teclado do Windows para português durante a sessão (o PC usa inglês por causa do teclado físico) e voltar ao desconectar.

## Prompts-modelo

**Escrever o plano da fase N:**
> Gabs Remote — escrever o plano da **fase N (nome)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (seções da fase), `docs/decisoes/`, o checklist da fase anterior em `docs/testes/` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks onde mexer. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

**Executar o plano da fase N:**
> Gabs Remote — executar o plano `docs/superpowers/plans/<arquivo>.md`. Leia o `CLAUDE.md` e o plano. Execução nativa (executing-plans), pedindo meu ok nos passos marcados. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

**Retomar uma execução interrompida:**
> Gabs Remote — continuar a execução de `docs/superpowers/plans/<arquivo>.md`. Confira no `git log` e nos checkboxes o que já foi feito e siga da próxima tarefa.
