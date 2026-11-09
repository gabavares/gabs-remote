# Rede de fora de casa

Como o tablet chega ao PC fora de casa, e como o app liga o PC. Diagnóstico da fase 3 (Task 1), feito em 09/11/2026. A decisão está em `docs/decisoes/0005-fora-de-casa.md`.

## Os caminhos possíveis

| Caminho | O que é | Resultado em 09/11/2026 |
|---|---|---|
| IPv6 direto | o tablet fala com o IPv6 global do PC, sem NAT | **não**: a Vivo entrega IPv6 ao PC (prefixo `2804:1b3:…`), mas o roteador barra conexões de entrada e não tem opção de firewall IPv6 |
| IPv4 com porta aberta | redirecionar as portas do host no roteador para o PC | **possível, mas não usado**: a linha tem IPv4 público (sem CGNAT); abrir as portas expõe o host à internet (decisão 0005) |
| Tailscale | rede privada entre os aparelhos do Gab (`docs/tailscale.md`) | **sim**, é o caminho de fora |

## O roteador (Askey da Vivo, `http://192.168.15.1`)

- Conexão PPPoE pela fibra (GPON). O IPv4 público muda quando o roteador reconecta.
- UPnP, DDNS e DMZ desligados.
- **Redirecionar Portas** (Configurações › Rede Local): `RuleName2`, UDP 8080 → `192.168.15.2:8080`. É a regra que a WOLskill da Alexa usava, e o app passa a usar a mesma.
- **Reserva de DHCP** (criada em 09/11/2026 com o ok do Gab): `DESKTOP-19H9KTG`, `18:C0:4D:6A:9B:2D` → `192.168.15.2`. Assim a regra do WoL nunca aponta para outro aparelho.
- Outras regras antigas (TCP 21, jogos) não são do Gabs Remote e ficaram como estavam.

## Wake-on-LAN

- **Em casa:** o app manda o pacote mágico por broadcast (código do upstream).
- **De fora:** o app manda o pacote mágico por UDP para `<IPv4 público de casa>:8080`; o roteador entrega ao PC pelo cabo. Nada de Alexa nem de serviço de terceiros. O IPv4 público de casa vem da página de presença na hospedagem (o PC atualiza enquanto está ligado) e do último valor conhecido pelo app.
- A hospedagem não pode mandar o pacote: a Hostinger bloqueia UDP de saída ("Operation not permitted", testado em 09/11/2026).
- Placa do PC (`tools/setup/conferir-wol.ps1`, 09/11/2026): "WoL ativo na placa Ethernet (Realtek PCIe GbE Family Controller)". O Início rápido do Windows está ligado; hoje não atrapalha (o WoL pela Alexa funciona). Se um dia o PC não ligar, é o primeiro suspeito.

## Como repetir o diagnóstico

1. **CGNAT:** `tracert -d -h 4 8.8.8.8`. Se o segundo ou terceiro salto estiver em `100.64.0.0/10`, a linha está em CGNAT. Em 09/11/2026 os saltos depois do roteador eram públicos.
2. **IPv4 público:** `curl.exe -4 https://ifconfig.me` (o mesmo valor aparece no Status do roteador).
3. **IPv6 de entrada:** com uma regra temporária no firewall do Windows (`New-NetFirewallRule -DisplayName 'Gabs Remote teste TCP' -Direction Inbound -Protocol TCP -LocalPort 47989 -Action Allow`, como administrador) e algo escutando na porta, pedir de fora `curl -6 http://[<ipv6-do-PC>]:47989/` (pela hospedagem: `ssh hostinger`). Tempo esgotado = barrado no roteador. Remover a regra no fim.
4. **UPnP:** `(New-Object -ComObject HNetCfg.NATUPnP).StaticPortMappingCollection` vazio = UPnP desligado.
5. **WoL de fora:** com o PC desligado, o tablet no 4G e "Ligar o PC" no app; o PC deve ligar em menos de 1 minuto.
