# Gabs Remote

Sistema próprio de acesso remoto entre o PC Windows do Gab (host) e um Galaxy Tab S10+ (app Android).

- **Host:** fork do [Sunshine](https://github.com/LizardByte/Sunshine) em `host/` ([gabs-remote-host](https://github.com/gabavares/gabs-remote-host)).
- **App:** fork do [moonlight-android](https://github.com/moonlight-stream/moonlight-android) em `android/` ([gabs-remote-android](https://github.com/gabavares/gabs-remote-android)).
- Módulos próprios virão por fases: microfone, webcam, clipboard e arquivos, atualizador e conectividade fora de casa.

O design completo está em [`docs/superpowers/specs/2026-11-06-gabs-remote-design.md`](docs/superpowers/specs/2026-11-06-gabs-remote-design.md).

## Estrutura

```
gabs-remote/
  host/          submódulo gabs-remote-host (fork do Sunshine)
  android/       submódulo gabs-remote-android (fork do moonlight-android)
  drivers/       tela virtual, microfone virtual, webcam virtual
  updater/       atualizador do host e assinatura do manifesto
  installer/     script do instalador
  web/           presença na hospedagem e, na fase 8, cliente web
  tools/         scripts de ambiente e de build, medidor de latência
  docs/          specs, planos, decisões e checklists (pt-BR)
  graphify-out/  grafo do projeto para o Claude
```

## Como compilar

O caminho do projeto tem espaço, e MSYS2, CMake e Gradle quebram com isso. **Todo build roda pela junção `C:\gr`**, que aponta para esta pasta:

```powershell
cmd /c mklink /J C:\gr "C:\Users\Gabriel\Desktop\Acesso remoto"
```

1. Clone com os submódulos:
   `git -c core.longpaths=true -c core.autocrlf=false clone --recurse-submodules https://github.com/gabavares/gabs-remote.git`
2. Confira o ambiente: `powershell -File C:\gr\tools\setup\verificar-ambiente.ps1` (o que estiver faltando está em [`docs/ambiente.md`](docs/ambiente.md)).
3. Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Testes]`
4. App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Instalar]`

## Licença

GPL-3.0, a mesma dos projetos de origem.
