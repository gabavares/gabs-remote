# Fase 1 — Ambiente e forks: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deixar o PC do Gab pronto para desenvolver o Gabs Remote: base dos forks reconfirmada, ferramentas instaladas, repositórios criados, e o host (Sunshine) e o app (moonlight-android) **compilando sem mudanças** e conectando do Tab S10+ ao PC.

**Architecture:** O repositório principal `gabs-remote` (esta pasta) recebe os dois forks como submódulos em `host/` e `android/`. Scripts PowerShell em `tools/` verificam o ambiente e compilam cada lado de forma repetível. Nenhuma mudança de produto nesta fase: o objetivo é ter uma linha de base que compila e funciona, para medir tudo que vier depois.

**Tech Stack:** Git + submódulos, GitHub CLI (`gh`), MSYS2 UCRT64 (toolchain do Sunshine no Windows: gcc, CMake, Ninja, Boost, Node), JDK 17 + Android SDK/NDK + Gradle wrapper (moonlight-android), PowerShell 5.1, Pester 5 (testes dos scripts).

**Spec:** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§3 Abordagem, §8 repositórios, §9.1 estrutura, §10 fase 1)

## Global Constraints
- Docs, notas e mensagens ao Gab em **pt-BR**; código e identificadores seguem o upstream (inglês).
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>` e a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Criar repositório no GitHub, fazer fork, dar push ou publicar Release: só com o ok explícito do Gab no chat**, pedido no momento do passo.
- Repositórios: `gabavares/gabs-remote` (principal), `gabavares/gabs-remote-host` (fork de LizardByte/Sunshine), `gabavares/gabs-remote-android` (fork de moonlight-stream/moonlight-android). Todos públicos (GPL-3.0).
- Nesta fase **não** alterar código dos forks. Só build, testes do upstream e documentação.
- Nada na hospedagem Hostinger é tocado nesta fase.
- Segredos (keystore, chaves, senhas) nunca entram em repositório.
- O PC tem Parsec Virtual Display e SuperDisplay instalados: **não desinstalar** nada sem o ok do Gab.

## Review Focus
1. **Espaço no caminho** (`C:\Users\Gabriel\Desktop\Acesso remoto`): MSYS2/CMake/Gradle quebram com espaço. Esperado: builds rodam por uma junção sem espaço `C:\gr` → pasta do projeto. Testado na Task 3 (`verificar-ambiente` falha se o build for chamado de caminho com espaço) e nas Tasks 5–6.
2. **Caminhos longos** nos submódulos do Sunshine (third-party aninhado) estourando 260 caracteres. Esperado: `core.longpaths=true` no repositório e clone recursivo sem erro. Checado na Task 4.
3. **Fim de linha CRLF** quebrando scripts shell e patches dos submódulos. Esperado: `core.autocrlf=false` nos submódulos e `.gitattributes` no principal. Checado na Task 4 (`git status` limpo nos submódulos logo após o clone).
4. **Monitor errado capturado** por causa dos adaptadores virtuais do Parsec/SuperDisplay. Esperado: o host transmite o monitor físico 2560×1440. Checado no teste de ponta a ponta da Task 7, que registra qual adaptador o Sunshine listou.
5. **Firewall do Windows bloqueando as portas** (TCP 47984, 47989, 47990, 48010; UDP 47998–48000, 48002, 48010). Esperado: o app acha e conecta. A Task 7 confere as regras antes do teste.

---

### Task 1: Reconfirmar a base dos forks

**Files:**
- Create: `docs/decisoes/0001-base-dos-forks.md`

**Interfaces:**
- Produces: a decisão final dos dois repositórios upstream (padrão: `LizardByte/Sunshine` e `moonlight-stream/moonlight-android`), usada nas Tasks 4–6.

- [ ] **Step 1: Coletar evidências pela API pública do GitHub** (sem login), para `LizardByte/Sunshine`, `ClassicOldSong/Apollo`, `moonlight-stream/moonlight-android` e `ClassicOldSong/moonlight-android` (Artemis):
  - data do último commit em `master`/`main`;
  - última release e a data dela;
  - licença;
  - se o README ou as releases citam tela virtual, microfone, caneta/libvirtualhid ou clipboard.

  Exemplo de chamada: `curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest`.
- [ ] **Step 2: Aplicar a regra de decisão.** Fica o upstream, a menos que ele não tenha commit nos últimos 90 dias *e* o fork tenha. Os recursos do Apollo/Artemis/Foundation entram depois, por port, nas fases 2 e 5.
- [ ] **Step 3: Escrever `docs/decisoes/0001-base-dos-forks.md`** com uma tabela das evidências (repo, último commit, última release, licença, recursos) e a decisão em uma frase.
- [ ] **Step 4: Commit** — `docs: decisão da base dos forks`.

### Task 2: Script de verificação do ambiente (com testes)

**Files:**
- Create: `tools/setup/verificar-ambiente.ps1`
- Create: `tools/setup/verificar-ambiente.Tests.ps1`

**Interfaces:**
- Produces: `tools/setup/verificar-ambiente.ps1 [-Json] [-SemAndroid]`. Com `-SemAndroid`, pula NDK e SDK. Imprime uma linha por ferramenta (`OK <nome> <versão>` ou `FALTA <nome> — <como instalar>`) e sai com código 0 só se tudo estiver OK. As funções internas, exportáveis por dot-source, são:
  - `Test-Ferramenta -Nome <string> -Comando <scriptblock> -VersaoMinima <version>` → `[pscustomobject]@{Nome; Ok; Versao; Dica}`
  - `Test-CaminhoSemEspaco -Caminho <string>` → `[bool]`
- Ferramentas verificadas:
  - git ≥ 2.40
  - gh ≥ 2.40
  - MSYS2 (existe `C:\msys64\ucrt64\bin\gcc.exe`)
  - cmake e ninja dentro do UCRT64
  - JDK 17 (`java -version`)
  - `ANDROID_HOME` definido, com `platform-tools\adb.exe`
  - NDK na versão pedida pelo `android/app/build.gradle`, quando o submódulo existir
  - Pester ≥ 5
  - junção `C:\gr` apontando para a pasta do projeto

- [ ] **Step 1: Escrever os testes Pester que falham.**
  - `Test-CaminhoSemEspaco 'C:\gr'` → `$true`
  - `Test-CaminhoSemEspaco 'C:\Users\Gabriel\Desktop\Acesso remoto'` → `$false`
  - `Test-Ferramenta` com um comando que devolve `'git version 2.45.1'` e mínimo `2.40` → `Ok=$true`, `Versao='2.45.1'`
  - com mínimo `3.0` → `Ok=$false` e `Dica` não vazia
  - com um comando que lança exceção → `Ok=$false`
- [ ] **Step 2: Rodar e ver falhar.** Antes, `Install-Module Pester -MinimumVersion 5 -Scope CurrentUser` se faltar. Depois: `Invoke-Pester tools/setup/verificar-ambiente.Tests.ps1`. Esperado: FAIL (funções não definidas).
- [ ] **Step 3: Implementar o script.** As versões são extraídas por regex `\d+(\.\d+)+` da saída de cada comando.
- [ ] **Step 4: Rodar os testes de novo.** Esperado: PASS.
- [ ] **Step 5: Commit** — `feat(tools): verificação do ambiente de desenvolvimento`.

### Task 3: Instalar as ferramentas e criar a junção

**Files:**
- Create: `docs/ambiente.md` (o que foi instalado, de onde, versões, onde fica)

**Interfaces:**
- Consumes: `verificar-ambiente.ps1` (Task 2).
- Produces: ambiente completo e a junção `C:\gr` → `C:\Users\Gabriel\Desktop\Acesso remoto`. **Todo build roda a partir de `C:\gr`.**

- [ ] **Step 1: Pedir o ok do Gab** para instalar Git atualizado, GitHub CLI, MSYS2, JDK 17 (Temurin) e Android SDK command-line tools. São downloads oficiais (winget e os sites dos projetos), somando cerca de 6–8 GB.
- [ ] **Step 2: Instalar via winget.** `winget install --id GitHub.cli`, `MSYS2.MSYS2`, `EclipseAdoptium.Temurin.17.JDK`.
  - Depois, no UCRT64, instalar os pacotes listados no `docs/building.md` do Sunshine (lido do fork na Task 4; se ainda não houver clone, ler pela web).
  - Android: baixar as command-line tools para `C:\Android\sdk`, definir `ANDROID_HOME` e rodar `sdkmanager "platform-tools" "platforms;android-<compileSdk>" "build-tools;<versão>" "ndk;<versão>"`, com as versões tiradas do `build.gradle` do moonlight-android.
- [ ] **Step 3: Criar a junção.** `cmd /c mklink /J C:\gr "C:\Users\Gabriel\Desktop\Acesso remoto"`.
- [ ] **Step 4: Login do GitHub CLI.** O Gab roda `gh auth login` no próprio terminal: o login é dele e o Claude não digita credenciais.
- [ ] **Step 5: Verificar.** `powershell -File C:\gr\tools\setup\verificar-ambiente.ps1`. Esperado: só linhas `OK`, exceto o NDK enquanto o submódulo não existir. Código de saída 0 com `-SemAndroid`.
- [ ] **Step 6: Escrever `docs/ambiente.md` e fazer commit** — `docs: ambiente de desenvolvimento`.

### Task 4: Repositórios no GitHub e submódulos

**Files:**
- Create: `.gitmodules`, `.gitattributes`, `README.md`
- Create (pastas com `.gitkeep`): `drivers/`, `updater/`, `installer/`, `web/`, `tools/build/`
- Modify: `.gitignore` (acrescentar `build/`, `*.apk`, `local.properties`, `.gradle/`)

**Interfaces:**
- Consumes: decisão da Task 1; `gh` autenticado (Task 3).
- Produces: `host/` = submódulo `https://github.com/gabavares/gabs-remote-host.git`; `android/` = submódulo `https://github.com/gabavares/gabs-remote-android.git`; remoto `origin` = `gabavares/gabs-remote`. Em cada fork, um remoto `upstream` apontando para o original.

- [ ] **Step 1: Pedir o ok do Gab** para criar os três repositórios públicos e dar o primeiro push.
- [ ] **Step 2: Criar os forks e o repositório principal.**
  - `gh repo fork LizardByte/Sunshine --fork-name gabs-remote-host --clone=false`
  - `gh repo fork moonlight-stream/moonlight-android --fork-name gabs-remote-android --clone=false`
  - `gh repo create gabavares/gabs-remote --public --source C:\gr --remote origin`
- [ ] **Step 3: Configurar o git** antes de adicionar os submódulos: `git config core.longpaths true`.
- [ ] **Step 4: Adicionar os submódulos** e baixar recursivamente.
  - `git submodule add https://github.com/gabavares/gabs-remote-host.git host`, e o mesmo para `android`.
  - `git submodule update --init --recursive`.
  - Em cada submódulo: `git config core.autocrlf false` e `git remote add upstream <original>`.
- [ ] **Step 5: Verificar.**
  - `git submodule status` lista `host` e `android` com hash, sem `-` ou `+`.
  - `git -C host status --porcelain` e `git -C android status --porcelain` saem vazios (sem CRLF sujando os arquivos).
- [ ] **Step 6: Criar o `README.md`** (o que é o projeto, a estrutura de §9.1 da spec, como compilar apontando para `tools/build/`), o `.gitattributes` (`* text=auto`, `*.ps1 text eol=crlf`, `*.sh text eol=lf`) e as pastas vazias.
- [ ] **Step 7: Commit e push** (já autorizados no Step 1) — `chore: repositório principal com submódulos host e android`.

### Task 5: Compilar o host sem mudanças

**Files:**
- Create: `tools/build/build-host.ps1`
- Create: `docs/testes/fase-1-checklist.md` (seção Host)

**Interfaces:**
- Consumes: ambiente da Task 3; `host/` da Task 4.
- Produces: `tools/build/build-host.ps1 [-Clean] [-Testes]`. Roda no shell UCRT64 do MSYS2 a partir de `C:\gr\host`:
  - `cmake -B build -G Ninja -S . -DBUILD_DOCS=OFF`, mais as opções do `docs/building.md`
  - `ninja -C build`
  - com `-Testes`, também o binário de testes do upstream (`build/tests/test_sunshine.exe`)

  Sai com código ≠ 0 em qualquer falha, e recusa rodar se `(Get-Location)` tiver espaço.

- [ ] **Step 1: Escrever o script** usando `C:\msys64\usr\bin\bash.exe -lc` com `MSYSTEM=UCRT64` e `CHERE_INVOKING=1`.
- [ ] **Step 2: Rodar o build.** `powershell -File C:\gr\tools\build\build-host.ps1 -Testes`. Esperado: o build termina, `C:\gr\host\build\sunshine.exe` existe e os testes do upstream passam. Anotar no checklist quantos passaram e quantos foram pulados.
- [ ] **Step 3: Conferir o comportamento com caminho com espaço.** Rodar a partir de `C:\Users\Gabriel\Desktop\Acesso remoto\host`. Esperado: o script recusa com mensagem em pt-BR mandando usar `C:\gr`.
- [ ] **Step 4: Commit** — `feat(tools): build do host`.

### Task 6: Compilar o app sem mudanças

**Files:**
- Create: `tools/build/build-android.ps1`
- Modify: `docs/testes/fase-1-checklist.md` (seção App)

**Interfaces:**
- Consumes: ambiente da Task 3; `android/` da Task 4.
- Produces: `tools/build/build-android.ps1 [-Testes] [-Instalar]`. A partir de `C:\gr\android`:
  - `.\gradlew.bat assembleNonRootDebug`
  - com `-Testes`, também `testNonRootDebugUnitTest`
  - com `-Instalar`, também `adb install -r` do APK gerado

  Se os nomes das variantes forem outros no `build.gradle`, use os que existirem e anote no checklist. Recusa caminho com espaço, como a Task 5.

- [ ] **Step 1: Escrever o script.**
- [ ] **Step 2: Rodar o build.** `powershell -File C:\gr\tools\build\build-android.ps1 -Testes`. Esperado: o APK de debug existe em `android/app/build/outputs/apk/`, e os testes unitários do upstream passam ou nenhum existe (anotar qual dos dois).
- [ ] **Step 3: Commit** — `feat(tools): build do app Android`.

### Task 7: Teste de ponta a ponta (linha de base)

**Files:**
- Modify: `docs/testes/fase-1-checklist.md` (seção Ponta a ponta)

**Interfaces:**
- Consumes: `sunshine.exe` (Task 5) e o APK (Task 6).
- Produces: a linha de base registrada (fps, latência mostrada no overlay do Moonlight, codec e qual monitor foi capturado), que a fase 2 usa para comparar.

- [ ] **Step 1: Conferir o firewall.**
  - Com `Get-NetFirewallRule`, verificar se existem regras de entrada para as portas TCP 47984, 47989, 47990, 48010 e UDP 47998–48000, 48002, 48010 no perfil Privado.
  - Se faltarem, pedir o ok do Gab para criar as regras de entrada com o nome `Gabs Remote (dev)`, só no perfil Privado. É uma mudança de configuração de segurança do sistema, então quem confirma é o Gab.
- [ ] **Step 2: Subir o host em modo console**, como administrador e não como serviço: `C:\gr\host\build\sunshine.exe`. Anotar no checklist quais adaptadores e monitores ele listou no log, e qual escolheu.
- [ ] **Step 3: Instalar o APK no Tab S10+.** Usar adb com depuração USB ativada pelo Gab, ou copiar o APK para o tablet; quem toca no tablet é o Gab.
- [ ] **Step 4: Parear e testar.**
  - Parear com o PIN pelo painel `https://localhost:47990`. O Gab cria o usuário do painel e digita a senha.
  - Abrir uma sessão "Desktop" na rede de casa em 1080p60 e depois em 2560×1440 a 120 fps (se o app permitir).
  - Anotar no checklist: fps, latência de decodificação e de rede do overlay, codec, monitor capturado e se o toque e o teclado funcionam.
- [ ] **Step 5: Commit** — `docs: linha de base da fase 1`.

### Task 8: Atualizar o grafo e o CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (comandos de build, a regra do `C:\gr`, onde fica cada coisa nos forks)
- Create: `.graphifyignore` (ou o arquivo de exclusões que o graphify usar), excluindo `host/third-party/`, `host/build/`, `android/**/build/`, `node_modules/` e `.gradle/`
- Modify: `graphify-out/` (rebuild)

- [ ] **Step 1: Configurar as exclusões** e rodar `/graphify . --update`. Se o detect passar de 500 arquivos, rodar em `host/src` e `android/app/src` e mesclar, como manda a skill do graphify.
- [ ] **Step 2: Verificar.** `graphify-out/GRAPH_REPORT.md` cita nós do host (captura, encoder) e do app (decoder, input), e o health check sai sem warning.
- [ ] **Step 3: Atualizar o `CLAUDE.md`** e fazer commit e push — `docs: grafo com os forks e comandos de build`.

---

## Próxima sessão

Ao terminar esta fase, **comece uma sessão nova** e use:

> Gabs Remote — escrever o plano da **fase 2 (Streaming em casa e fora via Tailscale)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§4, §5.2 item 3, §6.1, §6.2, §7, §9.3, §10), `docs/decisoes/`, `docs/testes/fase-1-checklist.md` (linha de base) e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar no fork do host e do app onde ficam a tela virtual, a entrada de caneta/toque e o serviço. Escreva o plano com a skill writing-plans, terminando com a seção "Próxima sessão".

Se a execução desta fase 1 parar no meio, use na sessão nova:

> Gabs Remote — continuar a execução da **fase 1**. Leia o `CLAUDE.md` e `docs/superpowers/plans/2026-11-06-fase-1-ambiente-e-forks.md`, confira no `git log` e nos checkboxes quais tarefas já foram feitas e siga da próxima.
