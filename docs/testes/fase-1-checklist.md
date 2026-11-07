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

Teste feito em 07/11/2026, por volta da 0h, no Wi-Fi de casa. Host em modo console como administrador (`C:\gr\host\build\sunshine.exe`) e app `Moonlight (Debug)` instalado no Tab S10+ pelo APK. Log completo do host em [`fase-1-log-host.md`](fase-1-log-host.md).

### Firewall e rede
- [x] A rede do PC estava como **Pública**. O Gab mudou para **Privada**.
- [x] Regras de entrada `Gabs Remote (dev) TCP/UDP`, só no perfil Privado, criadas pelo Gab com `tools\setup\firewall-dev.ps1` como administrador. Para desfazer: `Remove-NetFirewallRule -DisplayName 'Gabs Remote (dev)*'`.

### Monitores que o host listou
| Saída | Monitor | Resolução | Taxa | Principal |
|---|---|---|---|---|
| `\\.\DISPLAY1` | TCL 27G64 | 2560×1440 | 180 Hz | **sim** |
| `\\.\DISPLAY2` | SAMSUNG | 4096×2160 | 120 Hz | não |
| `\\.\DISPLAY3` | ARZOPA (portátil) | 1920×1080 | 60 Hz | não |

- [x] **Monitor capturado: o físico principal, TCL 27G64 2560×1440** (`Capture size 2560x1440`, `Desktop resolution [2560x1440]`, 180 Hz).
- Nenhum adaptador virtual do Parsec ou do SuperDisplay apareceu na lista (estavam inativos no momento do teste).
- GPU: **NVIDIA GeForce RTX 5060 Ti** (NVENC), com HAGS ligado. Encoders encontrados: H.264, HEVC e AV1 (todos `nvenc`). O YUV444 em AV1 não é suportado por essa GPU; HEVC e H.264 suportam.

### Linha de base (overlay de estatísticas do Moonlight)
| Medida | 1080p | 2560×1440 |
|---|---|---|
| FPS recebidos e renderizados | 33,58 | 64,44 |
| Decodificador | `c2.mtk.hevc.decoder.lowlatency` (HEVC) | `c2.mtk.hevc.decoder.lowlatency` (HEVC) |
| Quadros perdidos na rede | 0,00% | 0,00% |
| Latência média da rede | 8 ms (variação 0 ms) | 7 ms (variação 2 ms) |
| Processamento no host (mín/máx/média) | 1,6 / 2,4 / 1,8 ms | 2,3 / 92,6 / 5,6 ms |
| Tempo médio de decodificação | 8,51 ms | 0,31 ms |

- [x] Pareamento por PIN pelo painel `https://localhost:47990` funcionou.
- [x] Sessão "Desktop" abriu nas duas resoluções. Toque e teclado: o Gab relatou "tudo testado".

### Observações para a fase 2
- O FPS ficou abaixo do pedido (33 em 1080p, 64 em 1440p). O Sunshine só manda quadro quando a tela muda, então área de trabalho parada derruba o número. Na fase 2, medir com algo em movimento (vídeo ou janela arrastada) e conferir se a opção de 120 FPS estava ativa no app.
- O pico de 92,6 ms de processamento no host em 1440p é isolado (a média foi 5,6 ms), mas vale acompanhar.
- O tempo de decodificação em 1080p (8,51 ms) saiu bem maior que em 1440p (0,31 ms), o que é estranho. Provavelmente é medida de poucos quadros com a tela parada. Repetir na fase 2 com o medidor de latência (§9.3 da spec).
- O monitor certo foi escolhido sem configuração nenhuma, porque o TCL é o principal. A tela virtual da fase 2 muda isso.
