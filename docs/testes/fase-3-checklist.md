# Fase 3 — Checklist (rascunho)

Plano: `docs/superpowers/plans/2026-11-07-fase-3-fora-de-casa.md`. Decisão: `docs/decisoes/0005-fora-de-casa.md`.

## `WSASendMsg() failed: 10022` (Task 3)
- **Causa:** o host começa a mandar vídeo e áudio antes de a conexão de controle definir o endereço local da sessão. Até lá a origem é `0.0.0.0`, e o Windows recusa um `IP_PKTINFO` com ela (`WSAEINVAL`). O envio em lote falhava calado e o envio unitário logava cada pacote.
- **Evidência:** `sunshine.log.4` do serviço (07/11/2026): 462 linhas 10022, todas entre `New streaming session started` e `CLIENT CONNECTED`; nenhuma depois.
- **Correção (host `b26b0c36`):** sem origem definida, o pacote sai sem `PKTINFO` (origem escolhida pelo sistema); no lote, a opção de tamanho passa a ser a primeira mensagem de controle. Testes `SendSource.*`.
- **Efeito esperado:** nenhum 10022, e os primeiros quadros chegam ao tablet em vez de serem descartados no host.
- [ ] Verificar em sessão real (90 e 120 fps, casa e Tailscale) com o host novo instalado.
