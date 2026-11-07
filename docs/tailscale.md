# Acesso de fora pelo Tailscale

Fora de casa, o tablet chega ao PC pelo Tailscale, uma rede privada entre os aparelhos do Gab. O host já trata os endereços do Tailscale (`100.64.0.0/10`) como rede local, então o pareamento feito em casa vale também de fora. A escolha automática entre IPv6, redirecionamento de porta e Tailscale fica para a fase 3.

## Instalação (feita em 07/11/2026)

1. No PC: `winget install Tailscale.Tailscale`, entrar com a conta do Gab e ativar **Run unattended** no menu do ícone da bandeja (o Tailscale fica ligado antes do login no Windows, igual ao host).
2. No painel do Tailscale (login.tailscale.com, aba Machines): no PC, **Disable key expiry**. Sem isso a chave do PC expira em alguns meses e o acesso de fora cai.
3. No tablet: Tailscale pela Play Store, mesma conta.

| Aparelho | Nome na rede (MagicDNS) | IP |
|---|---|---|
| PC | `desktop-19h9ktg.tail740109.ts.net` | `100.99.120.91` |
| Tablet | `galaxy-tab-s10` | `100.86.150.28` |

## Usar de fora

1. No tablet, Tailscale ligado (o ícone de chave aparece na barra de status).
2. No Gabs Remote, o PC foi adicionado pelo nome `desktop-19h9ktg.tail740109.ts.net` (botão "+"). Ele aparece como o mesmo PC pareado em casa.
3. Abrir a sessão normalmente.

## Firewall

O `tools/setup/instalar-host.ps1` cria as regras `Gabs Remote Tailscale TCP` (47984, 47989, 48010) e `Gabs Remote Tailscale UDP` (47998–48010 e 48100, a do medidor), em todos os perfis de rede, mas só para endereços do Tailscale. O painel web (47990) fica fora. Para conferir: `netsh advfirewall firewall show rule name="Gabs Remote Tailscale TCP"`.

## Direto ou por servidor intermediário

O Tailscale tenta ligar os aparelhos direto; quando a rede não deixa, passa por um servidor dele (DERP), com mais latência. No PC:

```
& "C:\Program Files\Tailscale\tailscale.exe" status
& "C:\Program Files\Tailscale\tailscale.exe" ping galaxy-tab-s10
```

`direct <ip:porta>` é ligação direta; `relay "<cidade>"` ou `via DERP` é pelo servidor. Em casa, pelo Wi-Fi, a ligação foi direta (9 ms).

## Se cair

- Conferir nos dois aparelhos se o Tailscale está ligado e na mesma conta (`tailscale status` no PC lista o tablet).
- Se o PC sumiu da lista: no PC, abrir o Tailscale e entrar de novo; conferir no painel se a chave não expirou.
- Se o PC aparece mas a sessão não abre: `tailscale ping galaxy-tab-s10` no PC; se responder, testar a porta do host com `Test-NetConnection 100.99.120.91 -Port 47989` de outro aparelho da rede.
- A sessão depende da qualidade da internet dos dois lados: no 4G do Gab o resultado foi limitado pela conexão (o Google Remote Desktop, na mesma hora, ficou igual ou pior). No escritório o Gab usa o Wi-Fi.
