# Fase 4 — Checklist (rascunho; fecha na Task 11)

Plano: `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md`. Decisão 0006.

## Instalador sobre a instalação da fase 3 (Task 6, 09/11/2026)
- 1ª tentativa: falhou ao parar o serviço sem mexer em nada (o NSIS do MSYS2 gera instalador de **64 bits** e o caminho `Sysnative` não existe nele). Corrigido: o PowerShell é escolhido em `.onInit`.
- Instalador interativo por cima da fase 3: ✓. Serviço `GabsRemote` automático, recuperação 5 s / 5 s / 30 s, igual a antes.
- Regras de firewall iguais às de antes: só `Gabs Remote LAN TCP/UDP` (perfil Privado, `LocalSubnet`) e `Gabs Remote Tailscale TCP/UDP` (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`; painel 47990 fora do Tailscale). ✓
- `icacls config\updates`: só `AUTORIDADE NT\SISTEMA` e `BUILTIN\Administradores`, controle total, sem herança. ✓
- `config` preservada (credentials, apps.json, sunshine.conf, sunshine_state.json). ✓ Tablet conectou sem pedir PIN (Gab). ✓
- `GabsRemote-Setup-0.4.0.exe /S /ATUALIZACAO`: código 0 em 15 s, sem janela, serviço voltou sozinho, log `Sunshine version: 0.4.0` e `updater on (installed 0.4.0)`. ✓
- Entrada em "Aplicativos": Gabs Remote 0.4.0, Gab Tavares. ✓
- Login do painel com o mesmo usuário: pendente (conferir na Task 10).

## Updater do host em console, sem Release (Task 5)
- "Procurar atualizações" → estado `error`, "Nenhuma versão publicada ainda." no painel e `no Release published yet (HTTP 404)` no log. ✓
- Sessão aberta ao mesmo tempo sem engasgo: pendente (Task 11).

## Observação do Gab (09/11/2026)
- Tablet no 4G roteado pelo celular, pelo Tailscale: mais de 60 fps e menos de 40 ms, na mesma internet instável que antes tinha ficado ruim.

## CI (Task 9, 10/11/2026)
- 1º run: Pester falhou (stderr do OpenSSL virava exceção com `ErrorActionPreference Stop`) e o host falhou (pacotes do `qt6-static` que o upstream não lista). Corrigidos.
- 2º run (`42745627507`): tudo verde. Tempos: Presença (PHP) 10 s; Scripts (Pester) 2 min; App (testes unitários) 2,5 min; Host (build e testes, Gabs Remote + upstream) 28,6 min. ✓
