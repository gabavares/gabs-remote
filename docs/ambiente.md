# Ambiente de desenvolvimento

Instalado em 06/11/2026 (fase 1). Para conferir a qualquer momento:

```powershell
powershell -File C:\gr\tools\setup\verificar-ambiente.ps1
```

## Regra do caminho
A pasta do projeto (`C:\Users\Gabriel\Desktop\Acesso remoto`) tem espaço no nome, e MSYS2, CMake e Gradle quebram com isso. Por isso existe a junção **`C:\gr`**, que aponta para ela. **Todo build roda a partir de `C:\gr`.**

```powershell
cmd /c mklink /J C:\gr "C:\Users\Gabriel\Desktop\Acesso remoto"
```

## O que foi instalado

| Ferramenta | Versão | De onde | Onde fica |
|---|---|---|---|
| Git | 2.55.0 | já existia | `PATH` |
| GitHub CLI (`gh`) | 2.103.3 | `winget install --id GitHub.cli` | `C:\Program Files\GitHub CLI` |
| MSYS2 | — | `winget install --id MSYS2.MSYS2` | `C:\msys64` |
| gcc (UCRT64) | 16.2.0 | pacman | `C:\msys64\ucrt64\bin` |
| CMake (UCRT64) | 4.4.5 | pacman | `C:\msys64\ucrt64\bin` |
| Ninja (UCRT64) | 1.13.2 | pacman | `C:\msys64\ucrt64\bin` |
| JDK Temurin 17 | 17.0.21 | `winget install --id EclipseAdoptium.Temurin.17.JDK` | `C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot` (`JAVA_HOME`) |
| Android command-line tools | 15859902 | dl.google.com (SHA-256 conferido) | `C:\Android\sdk\cmdline-tools\latest` |
| Android platform-tools (adb) | 1.0.41 | sdkmanager | `C:\Android\sdk\platform-tools` |
| Android platform | android-37.0 | sdkmanager | `C:\Android\sdk\platforms` |
| Android build-tools | 37.0.0 e 36.0.0 (este instalado pelo Gradle) | sdkmanager | `C:\Android\sdk\build-tools` |
| Android NDK | 29.0.14206865 | sdkmanager | `C:\Android\sdk\ndk` |
| Node.js | 24.19.0 | já existia (nativo) | `PATH` (painel web do Sunshine) |
| Pester | 6.2.0 | `Install-Module Pester -Scope CurrentUser` | módulos do usuário |

Variáveis de usuário: `ANDROID_HOME=C:\Android\sdk` e `JAVA_HOME` (JDK 17 acima). Terminais abertos antes da instalação não as enxergam, e o mesmo vale para o `gh` no `PATH`: feche e abra o terminal.

## Pacotes do MSYS2 (UCRT64)
Os mesmos do `docs/building.md` do Sunshine, mais o ninja:

```bash
T=ucrt-x86_64
pacman -Syu   # duas vezes: a primeira fecha o shell
pacman -S --needed git mingw-w64-$T-boost mingw-w64-$T-cmake mingw-w64-$T-ninja mingw-w64-$T-cppwinrt \
  mingw-w64-$T-curl-winssl mingw-w64-$T-miniupnpc mingw-w64-$T-onevpl mingw-w64-$T-openssl \
  mingw-w64-$T-opus mingw-w64-$T-toolchain mingw-w64-$T-qt6-static mingw-w64-$T-MinHook mingw-w64-$T-nsis
```

O Node.js do MSYS2 **não** serve, porque o Sunshine exige o Node nativo do Windows.

O `qt6-static` ainda precisa destes pacotes, que o `building.md` não lista (descobertos no primeiro build):

```bash
pacman -S --needed mingw-w64-$T-libtiff mingw-w64-$T-pkgconf mingw-w64-$T-harfbuzz mingw-w64-$T-freetype \
  mingw-w64-$T-libjpeg-turbo mingw-w64-$T-brotli mingw-w64-$T-libwebp mingw-w64-$T-vulkan-headers \
  mingw-w64-$T-md4c mingw-w64-$T-double-conversion
```

O build do host usa o **Git for Windows** (`C:\Program Files\Git`) dentro do CMake, porque o git do MSYS2 quebra quando é chamado por um processo nativo.

## Pacotes do Android SDK
Versões tiradas do `android/app/build.gradle` (`compileSdk 37`, `ndkVersion "29.0.14206865"`):

```bash
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-37.0" "build-tools;37.0.0" "ndk;29.0.14206865"
```

## GitHub CLI
Login feito pelo Gab (`gh auth login`, pelo navegador), na conta `gabavares`.

## Problemas encontrados
- O `Invoke-WebRequest` do PowerShell 5.1 travou ao baixar o zip do Android. O `curl` resolveu.
- No `sdkmanager`, `platforms;android-37` não existe; o nome certo é `platforms;android-37.0`.
- Redirecionar "y" pelo PowerShell não aceita as licenças do SDK. Pelo bash (`yes | sdkmanager --licenses`) funciona.
