# Prompt para colar na sessão que controla o domínio/hospedagem

> Copie tudo abaixo da linha e cole na outra sessão. Depois traga a resposta para cá.

---

Estou planejando um sistema próprio de acesso remoto (PC Windows ↔ tablet Android) e preciso saber o que a minha hospedagem/servidor suporta. Responda de forma objetiva, item por item, verificando de verdade (painel, SSH, DNS, documentação do provedor) em vez de supor. Se algo não puder ser verificado, diga "não verificado" e o porquê.

1. **Provedor e plano:** nome do provedor, nome do plano e se é hospedagem compartilhada (cPanel/Plesk/hPanel), VPS, servidor dedicado ou cloud (AWS/GCP/Azure/Oracle/etc.).
2. **Acesso:** existe acesso SSH? Como root/sudo ou usuário limitado? Qual sistema operacional e versão (ex.: Ubuntu 22.04)?
3. **Recursos:** CPU (vCPUs), RAM, disco e **franquia/limite de tráfego mensal** (banda), e velocidade do link se informada.
4. **Processos persistentes:** posso rodar um processo 24/7 (ex.: um servidor Node/Go/Rust, ou Docker)? Docker está disponível?
5. **Portas e UDP:** posso abrir portas arbitrárias de entrada, incluindo **UDP** (ex.: 3478 e uma faixa 49152–65535) no firewall do servidor e do provedor? Há IP público IPv4 dedicado? Tem IPv6?
6. **DNS:** onde o DNS do domínio é gerenciado (registrador, Cloudflare, provedor)? Consigo criar subdomínios (ex.: `remote.meudominio.com`) com registros A/AAAA/CNAME? O domínio está atrás do proxy da Cloudflare?
7. **HTTPS/WebSocket:** consigo emitir certificado TLS (Let's Encrypt) para um subdomínio e servir WebSocket (wss://) nele?
8. **Localização do servidor:** em que país/datacenter fica (importa para latência a partir do Brasil)?
9. **Outros serviços já rodando** nesse servidor que eu não deva atrapalhar.

No final, dê um resumo de uma linha: "Dá para rodar um servidor de sinalização (WebSocket) + TURN/relay UDP? Sim / Não / Parcial — motivo".
