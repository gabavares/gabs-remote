# Fase 1 — Checklist (linha de base)

Builds sem nenhuma mudança nos forks, feitos em 06/11/2026 pela junção `C:\gr`.

## Host

- **Fork:** `host/` em `v2026.1106.201906` (`010f956`), base `LizardByte/Sunshine`.
- **Comando:** `powershell -File C:\gr\tools\build\build-host.ps1 -Testes`
- [x] Build termina e `host\build\sunshine.exe` existe (226,7 MB).
- [x] Testes do upstream (`build\tests\test_sunshine.exe`): **895 rodados, 882 passaram, 13 pulados, 0 falhas.**
  - Os pulados são testes de mouse HID absoluto (2) e do instalador Flatpak/comandos externos (11), que não se aplicam ao Windows.
- [x] Chamado de `C:\Users\Gabriel\Desktop\Acesso remoto\host`, o script recusa com a mensagem em pt-BR mandando usar `C:\gr` (código 2).

Ajustes que o build pediu (sem tocar no código do fork):
- Pacotes extras no MSYS2: `libtiff`, `harfbuzz`, `freetype`, `libjpeg-turbo`, `brotli`, `libwebp`, `vulkan-headers`, `md4c` e `double-conversion`. O `qt6-static` precisa deles e o `building.md` não os lista.
- O CMake usa o **Git for Windows** (`-DGIT_EXECUTABLE`). O git do MSYS2, chamado pelo CMake, quebra o `git submodule` das dependências baixadas.
- Paralelismo limitado a 8 (`-Jobs`). Com 16 o gcc estoura os 16 GB de RAM.
- O primeiro build leva cerca de 15 minutos; os seguintes são incrementais.

## App

- **Fork:** `android/` em `v12.2` (`b48494c`), base `moonlight-stream/moonlight-android`.
- **Comando:** `powershell -File C:\gr\tools\build\build-android.ps1 -Testes`
- Variantes: os sabores `root` e `nonRoot` existem no `build.gradle`, então os nomes do plano valem (`assembleNonRootDebug`, `testNonRootDebugUnitTest`).
- [x] APK de debug gerado: `android\app\build\outputs\apk\nonRoot\debug\app-nonRoot-debug.apk` (16,9 MB), em 2 min 39 s.
- [x] Testes unitários: **o upstream não tem nenhum** (`testNonRootDebugUnitTest NO-SOURCE`).
- [x] Chamado de caminho com espaço, o script recusa com a mensagem em pt-BR (código 2).
- Na primeira execução, o Gradle instalou sozinho o `build-tools;36.0.0`, que é o que o Android Gradle Plugin 9.4 pede.

## Ponta a ponta

_(Task 7: preenchido no teste com o Tab S10+.)_
