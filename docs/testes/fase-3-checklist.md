# Fase 3 — Checklist

Plano: `docs/superpowers/plans/2026-11-07-fase-3-fora-de-casa.md`. Decisão: `docs/decisoes/0005-fora-de-casa.md`. Rede: `docs/rede-fora.md`.

**Estado em 09/11/2026:** código das Tasks 1–8 feito e testado (host 946 testes, app 86, presença 21); host instalado no serviço e APK de release no tablet. Faltam as verificações no escritório e as Tasks 9 e 10 (roteiro abaixo).

## Uso real do Gab (09/11/2026)
O Gab quase não usa o tablet em casa: chega ao trabalho, conecta no Wi-Fi do escritório e acessa o PC pelo Tailscale. Por isso a troca casa ↔ fora no meio da sessão (Task 8 Step 4) não é testada; a reconexão continua valendo para quedas do Wi-Fi do escritório.

## Verificado

| Item | Evidência | |
|---|---|---|
| Diagnóstico da rede de fora | `docs/rede-fora.md`: IPv4 público (sem CGNAT), IPv6 de entrada barrado no roteador, regra UDP 8080 → PC, UPnP/DDNS desligados | ✓ |
| Reserva de DHCP do PC | `192.168.15.2` ↔ `18:C0:4D:6A:9B:2D` no roteador (ok do Gab) | ✓ |
| WoL ativo na placa | `conferir-wol.ps1`: "WoL ativo na placa Ethernet (Realtek…)"; Início rápido ligado (não atrapalha hoje) | ✓ |
| MAC pelo Tailscale | log: `100.99.120.91 has no MAC address; reporting the physical card 18:c0:4d:6a:9b:2d`, uma vez só; nenhum `Unable to find MAC address` | ✓ |
| `WSASendMsg` no início das sessões | antes: 462 linhas 10022 (07/11); depois da 1ª correção: 230 linhas 10014; com o host `d544f702`: **0** em duas sessões a 120 fps (09/11 21:35) | ✓ |
| Endereço de casa pelo Tailscale | antes o app guardava `100.99.120.91` como endereço de casa e conectava pelo Tailscale em casa; com o host `d544f702`, "Conectado por Rede de casa · 54 ms" e poll `192.168.15.2 (LAN)` | ✓ |
| Aviso do caminho | Toast "Conectado por Rede de casa · 54 ms" (o tempo é a resposta do `/serverinfo` com TLS, não a latência da imagem) | ✓ |
| Firewall | só `Gabs Remote LAN TCP/UDP` e `Gabs Remote Tailscale TCP/UDP` (`netsh`, 09/11); nenhuma porta aberta para a internet | ✓ |

## Causas e correções
- **10022:** o host manda vídeo e áudio antes de a conexão de controle definir o endereço local; `IP_PKTINFO` com 0.0.0.0 é recusado (`WSAEINVAL`). Correção (host `b26b0c36`): sem origem definida, sem `PKTINFO`.
- **10014:** a correção acima deixava o buffer de controle não nulo com tamanho 0, que o Windows recusa (`WSAEFAULT`). Correção (host `d544f702`): buffer nulo quando vazio. Comprovado num programa à parte: `PKTINFO 0.0.0.0` → 10022; buffer vazio não nulo → 10014; buffer nulo → ok.
- **LocalIP pelo Tailscale:** o `/serverinfo` devolvia o endereço do Tailscale como `LocalIP`; o app perdia o `192.168.15.2`. Correção (host `d544f702`): devolve o IPv4 da placa física.

## Pendente — roteiro para o escritório
1. **Caminho e latência (Task 10 Step 1):** no Wi-Fi do escritório, Nativo 120 fps. Anotar o Toast (deve ser Tailscale) e, no PC, `tailscale status` (direto ou DERP). Medidor (`docs/latencia.md`): clique e carimbo, 40 amostras. Comparar à mão com o Acesso Remoto do Google.
2. **15 min de uso real (Task 10 Step 2):** VS Code e navegador; anotar quedas e se a sessão voltou sozinha ("Reconectando…").
3. **WoL de fora (Task 7 Step 4):** antes de sair de casa, desligar o PC pelo Iniciar. No escritório (o app aprende o IP de casa pelo `ExternalIP` que o host descobre por STUN, host `f02a71f3`; conferido em 09/11: `191.32.66.196`): tocar no PC → Enviar WoL → "Ligando o PC… mm:ss" → a lista de apps abre sozinha. Anotar o tempo. Se aparecer "MAC ou IP de casa desconhecido", anotar.
4. **Task 9 (em casa, ~20 min):** latência ≤ 30 ms, um ajuste por vez.

## Fora da fase (decisões de 09/11/2026)
- **Presença na hospedagem não publicada:** o deploy do site (`rsync --delete` em `tools/post-receive` do repositório Gabtavares.com) apagaria a pasta. Código pronto em `web/presenca/`. Para publicar: uma exclusão `/gabs-remote/` no deploy ou a pasta dentro do repositório do site. Sem ela, o WoL de fora usa o último IP de casa que o app aprendeu.
- **Redirecionamentos antigos do roteador para o PC** (`RuleName1` TCP 21, "Battlefield 4", "GeoVision Webcam"; anteriores a esta fase): em 09/11/2026 nada no PC escutava nessas portas. O Gab conhece o motivo de cada um e decidiu mantê-los; a revisão fica para um projeto próprio de segurança. A reserva de DHCP faz essas regras sempre apontarem para o PC.
- Minors adiados da revisão final: `.superpowers/sdd/2026-11-07-fase-3-fora-de-casa/progress.md` (linhas `Final: minor (deferred)`).
