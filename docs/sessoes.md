# Roteiro de sessões do Claude

Cada fase usa **duas sessões novas**: uma para escrever o plano, outra para executá-lo. Isso mantém o contexto limpo e evita gastar tokens relendo conversa antiga. Tudo o que importa fica nos arquivos (spec, planos, decisões, checklists, grafo), nunca só na conversa.

Regra: **todo plano termina com a seção "Próxima sessão"**, com o prompt pronto. Ao fim de cada sessão, o Claude diz qual prompt usar.

## Onde estamos
| Fase | Plano | Execução |
|---|---|---|
| 0. Design | spec aprovada (06/11/2026) | — |
| 1. Ambiente e forks | `plans/2026-11-06-fase-1-ambiente-e-forks.md` | **feita (07/11/2026)**: host e app compilam, linha de base em `docs/testes/fase-1-checklist.md` |
| 2. Streaming (casa e fora via Tailscale) | **próxima sessão** | — |
| 3. Fora de casa completo | — | — |
| 4. Atualização e CI | — | — |
| 5. Áudio, mic, clipboard, arquivos | — | — |
| 6. Webcam | — | — |
| 7. Extras | — | — |
| 8. Cliente web | — | — |

## Próxima sessão (fase 2, plano)
> Gabs Remote — escrever o plano da **fase 2 (Streaming em casa e fora via Tailscale)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§4, §5.2 item 3, §6.1, §6.2, §7, §9.3, §10), `docs/decisoes/`, `docs/testes/fase-1-checklist.md` (linha de base) e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar no fork do host e do app onde ficam a tela virtual, a entrada de caneta/toque e o serviço. Escreva o plano com a skill writing-plans, terminando com a seção "Próxima sessão".

Notas da fase 1 para o plano da fase 2:
- Refazer a medição da linha de base com a tela em movimento: com a área de trabalho parada, o FPS caiu para 33 e 64.
- O host atual roda em modo console como administrador. Rodar como serviço fica para a fase 2.
- As regras de firewall de desenvolvimento (`Gabs Remote (dev)`) valem só na rede Privada. Na fase 2, decidir se o instalador cria regras próprias.

## Prompts-modelo

**Escrever o plano da fase N:**
> Gabs Remote — escrever o plano da **fase N (nome)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (seções da fase), `docs/decisoes/`, o checklist da fase anterior em `docs/testes/` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks onde mexer. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".

**Executar o plano da fase N:**
> Gabs Remote — executar o plano `docs/superpowers/plans/<arquivo>.md`. Leia o `CLAUDE.md` e o plano. Execução nativa (executing-plans), pedindo meu ok nos passos marcados. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

**Retomar uma execução interrompida:**
> Gabs Remote — continuar a execução de `docs/superpowers/plans/<arquivo>.md`. Confira no `git log` e nos checkboxes o que já foi feito e siga da próxima tarefa.
