Verifiquei pela API da Hostinger (pedidos, sites, DNS e domínio), por SSH no servidor e com um teste real de portas feito do seu PC.

**1. Provedor e plano**
- Hostinger, plano `hostinger_premium_v3` (Premium), pedido ativo desde 16/09/2026.
- É hospedagem compartilhada gerenciada pelo hPanel. O servidor roda CloudLinux, o kernel `4.18.0-…lve.el8`, que isola cada conta (LVE).
- Não é VPS nem cloud.

**2. Acesso**
- Tem SSH: `ssh hostinger`, na porta 65002, com o usuário `u872814721`.
- O usuário é limitado: não existe `sudo` e não há root.
- O sistema é baseado em RHEL/AlmaLinux 8 (CloudLinux), mas a versão exata não foi verificada: `/etc/os-release` está escondido para a conta.

**3. Recursos**
- O que o SSH mostra é a máquina física inteira, dividida com outros clientes: 48 núcleos, 257 GB de RAM e 7 TB de disco com 84% ocupado. Isso não é o que o seu plano recebe.
- Você usa 2,3 GB do disco.
- Os limites do plano (CPU, RAM, processos por conta e tráfego) não foram verificados: a API não informa e a conta não consegue ler os limites do LVE. A cota de cada coisa está no painel do hPanel.

**4. Processos persistentes**
- Na prática, sim. O `node ~/vagabs/iniciar.js` está rodando há 8 dias, e o `vigia.sh` o religa de minuto em minuto quando ele cai.
- Há Node 20, 22 e 24 em `/opt/alt/`. Não há Go, Rust nem Docker, e não dá para instalar Docker sem root.

**5. Portas, UDP e IP**
- Não é possível abrir porta de entrada. Fiz o teste: o servidor conseguiu reservar a porta TCP 49200 e a UDP 3478, mas nada enviado do seu PC chegou. No mesmo IP, a porta do SSH respondeu, então o bloqueio é o firewall da Hostinger, e você não tem acesso a ele.
- O IPv4 é 147.93.38.23, mas é compartilhado: a máquina tem vários IPs, todos de uso comum. Não há IP dedicado.
- Há IPv6 de saída (`2a02:4780:13:992::…`). Se ele aceita conexões de entrada não foi verificado, e o mesmo firewall deve bloquear.

**6. DNS**
- O DNS é gerenciado pela própria Hostinger (`lunar` e `solar.dns-parking.com`). O domínio foi registrado lá e está travado, com proteção de privacidade.
- Dá para criar subdomínios com registros A, AAAA ou CNAME pela API ou pelo hPanel.
- Não usa Cloudflare. Mas o domínio principal e o `www` passam pela CDN da Hostinger (`cdn.hstgr.net`), que funciona como um proxy. O `ftp` aponta direto para o IP.

**7. HTTPS e WebSocket**
- O certificado Let's Encrypt para um subdomínio sai pelo hPanel. Pelo padrão da Hostinger isso funciona, mas não testei.
- Servir `wss://` não foi verificado e é improvável. O processo Node não pode ser alcançado de fora pela porta dele (item 5), e o servidor web compartilhado não costuma repassar conexões WebSocket para um processo seu. Os apps Node.js do hPanel também parecem ser recurso dos planos Business e Cloud, não do Premium: a própria API da Hostinger cita só esses dois ao falar de Node.js.

**8. Localização**
- Brasil. O nome do servidor é `br-asc-web892.main-hosting.eu`. A cidade exata não foi verificada (o mais provável é São Paulo), mas a latência a partir do Brasil é boa.

**9. O que já roda e não deve ser atrapalhado**
- O site `gabtavares.com`, com o `/privado`, o conector `/mcp` e o hook de publicação.
- O Vagabs (`node iniciar.js`), mantido no ar pelo `vigia.sh`.
- A fila e o executor do Claude do servidor, que roda uma execução por vez.
- Os e-mails da Hostinger (MX, SPF, DKIM, DMARC) e a pasta `/sample`.
- Detalhe: o servidor não tem o comando `crontab`, então os agendamentos ficam no cron do hPanel.

**Resumo:** Dá para rodar um servidor de sinalização (WebSocket) + TURN/relay UDP? **Não**. A hospedagem compartilhada mantém um processo Node no ar, mas o firewall bloqueia toda porta de entrada fora as do provedor, inclusive UDP, e não há root, Docker nem IP dedicado. Para TURN e sinalização própria, o caminho é uma VPS (a KVM 1 da Hostinger já basta) ou um TURN gerenciado.