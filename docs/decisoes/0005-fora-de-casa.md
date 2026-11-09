# 0005 — Fora de casa: caminho, Wake-on-LAN e segurança

**Data:** 09/11/2026 · **Fase:** 3 · **Status:** decidida pelo Gab (07/11 e 09/11/2026)

## Contexto
A spec (§5.2) previa, em ordem: IPv6 direto, IPv4 com porta aberta e Tailscale; (§5.3) o WoL de fora pelo mesmo mecanismo da Alexa; e (§5.4) 2º fator e bloqueio do PC ao desconectar. O diagnóstico de 09/11/2026 está em `docs/rede-fora.md`.

## Decisão
1. **Sem 2º fator e sem bloqueio do PC ao desconectar** (Gab, 07/11/2026): ele mora sozinho e não precisa dessa privacidade. O pareamento por PIN e certificados continua.
2. **Sessão de fora pelo Tailscale, sem portas abertas** (Gab, 09/11/2026). O IPv6 de entrada é barrado pelo roteador, sem opção para liberar. O IPv4 público permitiria abrir as portas, mas isso põe o host, que roda como SYSTEM, atendendo qualquer um na internet: uma falha no código que lê a rede antes do pareamento daria controle total do PC. O Gab pediu o caminho seguro se houvesse risco sério. Com IPv4 público em casa, o Tailscale tende a conectar direto (sem DERP); a medição fica na Task 10.
3. **WoL próprio pelo roteador**, sem Alexa nem terceiros (Gab, 09/11/2026): o app manda o pacote mágico por UDP para `<IPv4 público de casa>:8080`, porta que o roteador já redireciona ao PC (regra criada para a WOLskill). O PC tem IP reservado no DHCP (`192.168.15.2`).
4. **Presença na hospedagem: sim, só com o que o WoL precisa.** O IPv4 público muda (PPPoE), e a hospedagem guarda o último valor que o PC informou, para o app achar a casa com o PC desligado. A hospedagem não manda o pacote (a Hostinger bloqueia UDP de saída).

## Consequências
- O plano da fase 3 encolhe: o host não ganha regras de firewall para a internet nem UPnP (Task 5); o app escolhe entre rede de casa, Tailscale e endereço manual (Task 6), sem candidatos IPv6/IPv4 públicos; o tipo do WoL de fora é `ROTEADOR` (Task 7).
- Continua a dependência do Tailscale (conta e servidor de coordenação deles). Saída futura sem terceiros: um WireGuard próprio embutido no app, com uma única porta UDP aberta, muda para quem não tem a chave (opção para a fase 7).
- Se o Gab trocar de roteador ou a Vivo resetar as configurações, refazer a regra UDP 8080 e a reserva de DHCP (`docs/rede-fora.md`).
