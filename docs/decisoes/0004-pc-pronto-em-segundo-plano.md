# 0004 — PC pronto com o app em segundo plano

**Data:** 07/11/2026 · **Fase:** 2 · **Status:** decidida pelo Gab (07/11/2026)

## Contexto
No upstream, quando o app do tablet sai da tela da sessão (Alt+Tab, Home, recentes), a transmissão para e o host desfaz a configuração de telas na hora: a tela virtual some, os monitores físicos voltam e o teclado volta ao inglês. Voltar ao app religa tudo, o que leva alguns segundos e faz os monitores piscarem. O Gab usa o tablet fora de casa e troca de app com frequência.

## Decisão
- **Segundo plano** (Alt+Tab, Home, recentes): a transmissão pausa, mas o host mantém a tela virtual e o teclado da sessão. Voltar ao app reaproveita a tela virtual (`reusing the virtual display`).
- **Voltar** ou **Desconectar** no menu da sessão: o app encerra o app no host (`/cancel`) e o PC é liberado na hora.
- **Sem tempo limite** (escolha do Gab): se o app for fechado à força ou o tablet sumir da rede, o PC fica pronto até a próxima conexão. Para liberar pelo próprio PC: encerrar o app no painel do host (`https://localhost:47990`).
- Trocar de perfil com o PC pronto desfaz a configuração antes de criar a tela na resolução nova.

## Consequências
- Enquanto o PC está pronto, os monitores físicos ficam desligados. Quem estiver no PC precisa encerrar pelo painel.
- O registro de telas do upstream (`config/display_device.state`) não pode citar a tela virtual: depois de um reinício do host ela não existe mais e a reversão ficava presa (corrigido no host `eaa0d85a`, ver `docs/testes/fase-2-checklist.md`).
- Código: host `src/gabs/virtual_display.cpp` (`should_revert_on_session_end`, `prepare_launch`, `strip_virtual_displays`), `src/stream.cpp`, `src/process.cpp`, `src/nvhttp.cpp`; app `gabs/session/SessionExit.java` e `Game.onStop`.
