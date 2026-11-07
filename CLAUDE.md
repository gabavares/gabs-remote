# Gabs Remote

Sistema próprio de acesso remoto: PC Windows do Gab (host) ↔ Galaxy Tab S10+ (app Android). Fork do Sunshine (host) + fork do moonlight-android (app), com módulos próprios (microfone, webcam, clipboard/arquivos, updater, conectividade remota).

- **Spec (fonte da verdade do design):** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md`
- **Planos de implementação:** `docs/superpowers/plans/` (um por fase)
- **Identidade visual:** design system GAB/S. Tokens, ícone e regras em `docs/marca/README.md` (cópia do DESIGN.md e do tokens.css em `docs/marca/gabs-design-system/`). No código, cores só de `tools/marca/cores.json`.
- **Hospedagem do Gab:** `docs/resposta servidor.md` — Hostinger compartilhada, sem portas de entrada; não serve de relay.

## Como trabalhar aqui
- Idioma: tudo em pt-BR (docs, notas de versão, UI). Código e identificadores em inglês, seguindo o upstream.
- Nunca mexer no que já roda na hospedagem (site gabtavares.com, Vagabs, executor do Claude).
- Mudanças nos forks: pequenas, em módulos/pastas próprias, para facilitar merge do upstream.
- Publicar Release, criar repositório no GitHub ou dar push: só com o ok do Gab.
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>`.
- Segredos (keystore do APK, chave Ed25519 do manifesto, senhas) nunca entram no repositório.

## Build (fase 1)
- **Todo build roda por `C:\gr`**, a junção sem espaço para esta pasta. MSYS2, CMake, Ninja e Gradle quebram com o espaço de "Acesso remoto", e os scripts recusam (código 2) se chamados de um caminho com espaço.
- Conferir o ambiente: `powershell -File C:\gr\tools\setup\verificar-ambiente.ps1` (testes: `Invoke-Pester C:\gr\tools\setup\verificar-ambiente.Tests.ps1`).
- Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Clean] [-Testes] [-Jobs 8]` gera `host\build\sunshine.exe`. O primeiro build leva cerca de 15 minutos. Não passe de 8 jobs: com 16 GB de RAM, o gcc estoura.
- App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Instalar]` gera `android\app\build\outputs\apk\nonRoot\debug\app-nonRoot-debug.apk`. O upstream não tem testes unitários.
- Rodar o host para teste: PowerShell como administrador, `cd C:\gr\host\build; .\sunshine.exe`. Painel em `https://localhost:47990`. As portas ficam liberadas pelo `tools\setup\firewall-dev.ps1` (só no perfil Privado).
- O que foi instalado e por quê: `docs/ambiente.md`. Linha de base de desempenho: `docs/testes/fase-1-checklist.md`.
- Os scripts `.ps1` são salvos em UTF-8 **com BOM**, porque o PowerShell 5.1 lê os acentos errado sem ele. No PowerShell, variáveis não diferenciam maiúsculas (`$testes` sobrescreve o parâmetro `$Testes`).
- Submódulos: `host/` (gabavares/gabs-remote-host, `upstream` = LizardByte/Sunshine) e `android/` (gabavares/gabs-remote-android, `upstream` = moonlight-stream/moonlight-android). Clone com `git -c core.longpaths=true -c core.autocrlf=false clone --recurse-submodules`.

## Onde fica cada coisa nos forks
- **Host (`host/src/`):** `video.cpp` (pipeline de captura → encoder), `nvenc/` (encoder NVIDIA), `platform/windows/display_*.cpp` (captura DXGI/WGC), `display_device.cpp` (escolha e configuração do monitor), `input.cpp` + `platform/windows/input.cpp` (toque, caneta, teclado, mouse), `audio.cpp`, `stream.cpp`/`rtsp.cpp` (sessão de rede), `nvhttp.cpp` (pareamento), `confighttp.cpp` (painel web), `config.cpp`.
- **App (`android/app/src/main/java/com/limelight/`):** `Game.java` (tela da sessão), `binding/video/MediaCodecDecoderRenderer.java` (decodificador), `binding/input/` (toque, teclado, controle, captura), `binding/audio/`, `computers/` e `discovery/` (achar e parear PCs), `preferences/`. Núcleo do protocolo em C: `android/app/src/main/jni/moonlight-core/moonlight-common-c/`.
- O grafo (`graphify-out/`) cobre só `host/src`, `android/app/src` e os docs do projeto; as exclusões ficam no `.graphifyignore`.

## Sessões
- Cada fase = uma sessão para o plano e outra para a execução. Roteiro e prompts-modelo em `docs/sessoes.md`.
- Todo plano termina com "Próxima sessão" (prompt pronto). Ao fechar uma sessão, atualize `docs/sessoes.md` e diga ao Gab qual prompt usar.
- Não refaça o que está nos arquivos: a spec, os planos, `docs/decisoes/` e os checklists são a memória do projeto.

## graphify
Este projeto tem um grafo de conhecimento em `graphify-out/`.
- Antes de perguntas de arquitetura ou de "onde fica X", leia `graphify-out/GRAPH_REPORT.md` e use `/graphify query "<pergunta>"`.
- Depois de mudar arquivos de forma relevante (nova fase, forks adicionados), rode `/graphify . --update`.
