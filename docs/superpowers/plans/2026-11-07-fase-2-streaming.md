# Fase 2 — Streaming em casa e fora via Tailscale: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O Gab usa o Gabs Remote no Tab S10+ em casa e no 4G/5G (pelo Tailscale): app e host com a marca Gabs Remote, tela virtual na resolução do tablet a até 120 Hz, perfis de tela, S Pen completa, modos de toque, teclado com todos os atalhos, host como serviço que sobe com o PC, e um medidor de latência que mede clique-até-imagem.

**Architecture:** As mudanças nos forks ficam em pastas próprias (`host/src/gabs/`, `host/src/platform/windows/gabs/`, `android/app/src/main/java/com/limelight/gabs/`) e tocam o código do upstream só nos pontos de encaixe (pedido de sessão em `nvhttp.cpp`, escolha da saída em `video.cpp`, revert em `display_device.cpp`, toque em `Game.java`, URL de launch em `NvHTTP.java`). O app pede o perfil de tela com um parâmetro novo no `/launch` (`grDisplay`); o host cria uma tela virtual por cliente com um driver IddCx assinado, atrás de uma interface `driver_t` para o driver poder ser trocado. O medidor de latência é um programa à parte no PC (`tools/latencia/`), que não toca no fork, mais um módulo no app.

**Tech Stack:** C++20 + GoogleTest (host, build por MSYS2 UCRT64), Java 17 + JUnit 4 (app, Gradle), C# .NET 8 WinForms + xUnit (marcador de latência), Python 3 + Pillow + pytest (ícones), PowerShell 5.1 + Pester 5 (scripts), Tailscale (oficial, no PC e no tablet).

**Spec:** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§4, §5.2 item 3, §6.1, §6.2, §7, §8 keystore, §9.3, §10 fase 2). Decisões: `docs/decisoes/0001-base-dos-forks.md`, `docs/decisoes/0002-marca-e-application-id.md`. Linha de base: `docs/testes/fase-1-checklist.md`.

## Global Constraints
- Docs, notas, UI e mensagens ao Gab em **pt-BR**; código e identificadores em inglês, seguindo o upstream.
- **Todo build roda por `C:\gr`** (junção sem espaço). Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Testes] [-Jobs 8]`, nunca mais de 8 jobs. App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Instalar]`.
- Testes do host: `C:\gr\host\build\tests\test_sunshine.exe --gtest_filter=<Suite>.*`. Testes do app: `build-android.ps1 -Testes` (roda `testNonRootDebugUnitTest`).
- Scripts `.ps1` em UTF-8 **com BOM**. No PowerShell, variáveis não diferenciam maiúsculas.
- Commits nos submódulos e no principal com `gabavares <43415454+gabavares@users.noreply.github.com>` e a linha `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit de submódulo primeiro, depois o principal registrando o ponteiro novo.
- **Push, Release, criar repositório: só com o ok do Gab no chat.** Instalar driver, serviço ou regra de firewall, e desinstalar qualquer coisa: o Gab roda o comando de administrador ou dá o ok no momento.
- Segredos (keystore, senhas) **nunca** entram em repositório nem na conversa. O Gab digita as senhas.
- Parsec Virtual Display e SuperDisplay continuam instalados: **não desinstalar** sem o ok do Gab.
- `applicationId` definitivo: `com.gabtavares.gabsremote` (decisão 0002). Não muda depois da primeira Release.
- Layout próprio das telas do app: **fase 7**. Interface nova da fase 2 usa só componentes padrão do Android (`PopupMenu`, `AlertDialog`, `Toast`, telas de preferência do upstream).
- Parâmetro novo do `/launch`: `grDisplay` com os valores `virtual` ou `mirror`. Ausente = comportamento do upstream.
- Nome do serviço do Windows: `GabsRemote`; nome exibido: `Gabs Remote`.
- Pasta de instalação de desenvolvimento do host: `C:\Program Files\Gabs Remote`. A configuração continua em `<pasta>\config` nesta fase; a mudança para `%ProgramData%\GabsRemote` (§8) vai junto com o instalador na fase 4.

## Review Focus
1. **O driver de tela virtual falha ou não está instalado.** Esperado: a sessão abre mesmo assim no monitor físico (como "Espelhar"), com aviso no log. Teste `VirtualDisplayLaunch.FallsBackToMirrorWhenDriverFails` na Task 5.
2. **O host cai ou é morto no meio da sessão.** Esperado: na próxima subida, telas virtuais órfãs são removidas e os monitores físicos voltam como estavam. Teste `VirtualDisplayManager.StartupCleanupRemovesAll` (Task 5) e item manual na Task 11 (matar `sunshine.exe` pelo Gerenciador de Tarefas).
3. **Reconexão do mesmo tablet (troca de Wi-Fi para 4G) gera um `/launch` novo.** Esperado: reaproveita a tela virtual do mesmo cliente em vez de criar uma segunda. Teste `VirtualDisplayManager.EnsureReusesSameClient` (Task 5).
4. **Palma da mão na tela enquanto desenha com a S Pen.** Esperado: toques de dedo são ignorados enquanto a caneta está perto (hover ou contato) e por 300 ms depois que ela sai. Testes `TouchModePolicyTest` (Task 7).
5. **Cliente sem o parâmetro `grDisplay`** (Moonlight oficial no celular, ou o app antigo). Esperado: o host se comporta como o upstream, sem tela virtual. Teste `VirtualDisplayLaunch.ParsesDisplayChoice` (Task 5).

---

### Task 1: Escolher e instalar o driver de tela virtual

**Files:**
- Create: `docs/decisoes/0003-driver-tela-virtual.md`
- Modify: `docs/ambiente.md` (seção "Driver de tela virtual": versão, de onde veio, como reinstalar)

**Interfaces:**
- Produces: o driver escolhido instalado no PC, e na decisão 0003: nome, versão, licença do header/SDK que o host vai incluir, e a API de criar/remover monitor (IOCTL ou pipe) com resolução e Hz arbitrários. A Task 5 implementa `driver_t` em cima disso.

- [ ] **Step 1: Levantar os dois candidatos** da spec (H2): **SudoVDA** (`SudoMaker/SudoVDA`, usado pelo Apollo em `src/platform/windows/virtual_display.cpp`) e **Virtual-Display-Driver** (`VirtualDrivers/Virtual-Display-Driver`, assinado pela SignPath). Para cada um anotar: assinatura (instala no Windows 10 22H2 com Secure Boot, sem test-signing?), licença, se cria monitor sob demanda com resolução e Hz pedidos (2800×1752 a 120 Hz), se remove sozinho quando o processo que o criou morre (watchdog), última release.
- [ ] **Step 2: Aplicar a regra.** Fica o **SudoVDA**, a menos que ele não instale assinado no Windows 10 22H2 ou não crie 2800×1752 a 120 Hz; nesse caso, o Virtual-Display-Driver. Motivo do padrão: criação sob demanda por cliente, watchdog e código do Apollo (GPL-3.0) pronto para portar.
- [ ] **Step 3: Instalar o driver escolhido (com o ok do Gab, como administrador).** Antes, o Gab ativa os adaptadores do **Parsec** e do **SuperDisplay** (abrindo os dois apps). Depois de instalar, conferir no Gerenciador de Dispositivos que os três adaptadores convivem e rodar `C:\gr\host\build\dxgi-info.exe` (anotar as saídas listadas).
- [ ] **Step 4: Criar um monitor de teste 2800×1752 @ 120 Hz** com a ferramenta do próprio driver (o app de controle do SudoVDA ou o XML/pipe do VDD), conferir em Configurações > Tela que aparece com essa resolução e taxa, e remover.
- [ ] **Step 5: Escrever a decisão 0003** (contexto, tabela dos dois candidatos, decisão, como o host chama a API, convivência com Parsec/SuperDisplay) e a seção em `docs/ambiente.md`. Commit — `docs: driver da tela virtual (decisão 0003)`.

### Task 2: Marca Gabs Remote no app, applicationId e keystore

**Files:**
- Create: `tools/marca/cores.json`, `tools/marca/gerar-icones.py`, `tools/marca/test_gerar_icones.py`, `docs/marca/README.md` (cores e como regenerar)
- Create: `docs/segredos.md`
- Modify: `android/app/build.gradle` (applicationId, nomes, `signingConfigs.release`, `testImplementation`)
- Modify: `android/app/src/main/res/mipmap-*/ic_launcher*.png`, `android/app/src/main/res/values/colors.xml` (`ic_launcher_background`), `android/app/src/main/res/drawable/app_icon.png`
- Modify: `tools/build/build-android.ps1` (`-Release`)
- Modify: `.gitignore` (`keystore.properties`)

**Interfaces:**
- Produces: `python tools/marca/gerar-icones.py --saida-android <res> --saida-host <dir>` gera todos os ícones a partir de **uma** função `desenhar_marca(tamanho: int, primaria: str, fundo: str, com_fundo: bool) -> PIL.Image.Image`; a linha de comando chama `gerar(saida_android: Path | None = None, saida_host: Path | None = None) -> None`, que os testes usam direto (o arquivo se chama `gerar-icones.py`, então os testes o carregam com `importlib.util.spec_from_file_location`). A Task 3 usa a mesma ferramenta para o host (`gabs-remote.ico` 16/24/32/48/256, `gabs-remote-256.png`, `favicon.ico`).
- Produces: `tools/marca/cores.json` (`{"primaria": "#RRGGBB", "fundo": "#RRGGBB"}`), a única fonte das cores da marca, lida pelo `gerar-icones.py` e usada na Task 3. A primária é o **azul elétrico do sistema visual GAB/S**, e o fundo é um tom escuro que combine com ela. O Gab passa os valores no Step 1.
- Produces: `build-android.ps1 -Release` gera `android\app\build\outputs\apk\nonRoot\release\app-nonRoot-release.apk` assinado; sai com código 5 e mensagem em pt-BR se `%USERPROFILE%\.gabs-remote\keystore.properties` não existir.

- [ ] **Step 1: Pegar com o Gab as cores do GAB/S** (o hex do azul elétrico e, se houver, o fundo escuro que o GAB/S usa; a pasta do GAB/S no servidor não guarda a paleta) e gravar `tools/marca/cores.json`. (O `applicationId` `com.gabtavares.gabsremote` já foi confirmado em 07/11/2026.) Mostrar a ele uma prévia do ícone (PNG 512 gerado pelo script do Step 3) antes de trocar os arquivos do app.
- [ ] **Step 2: Escrever os testes pytest que falham** em `tools/marca/test_gerar_icones.py`:
  - `desenhar_marca(192, '#1E5BFF', '#0B1020', True).size == (192, 192)` (valores só de teste)
  - com `com_fundo=False`, o pixel `(0, 0)` tem alfa 0 (o primeiro plano do ícone adaptativo é transparente fora da marca)
  - `gerar(saida_android=tmp)` cria `mipmap-mdpi/ic_launcher.png` com 48 px, `mipmap-xxxhdpi/ic_launcher.png` com 192 px e `mipmap-xxxhdpi/ic_launcher_foreground.png` com 432 px (108 dp × 4)
  - `gerar(saida_host=tmp)` cria `gabs-remote.ico` contendo os tamanhos 16, 24, 32, 48 e 256
  Rodar `python -m pytest tools/marca -q`: FAIL (módulo sem funções).
- [ ] **Step 3: Implementar `tools/marca/gerar-icones.py`** com Pillow (`pip install pillow pytest` se faltar). A marca: quadrado arredondado na cor de fundo, um "G" em arco grosso na cor primária com uma seta de cursor no vão do G. Os tamanhos legados por densidade são 48/72/96/144/192 px; os de primeiro plano, 108/162/216/324/432 px, com a marca dentro dos 66 dp centrais. Rodar os testes: PASS.
- [ ] **Step 4: Trocar a marca no app.** Rodar o script com `--saida-android android/app/src/main/res`. Em `colors.xml`, `ic_launcher_background` = o `fundo` de `cores.json`, e uma cor nova `gabs_primary` = a `primaria`, usada como `colorAccent`/`colorPrimary` no tema do upstream (`values*/styles.xml`), sem mexer em layout. Em `build.gradle`:
  - `nonRoot`: `applicationId "com.gabtavares.gabsremote"`; `root`: `"com.gabtavares.gabsremote.root"`.
  - `debug`: `app_label` = `Gabs Remote (Debug)`, `app_label_root` = `Gabs Remote (Root Debug)`; mantém `applicationIdSuffix ".debug"`.
  - `release`: tira o `applicationIdSuffix ".unofficial"` e o comentário do upstream sobre ele (o pedido do upstream é justamente trocar o ID); `app_label` = `Gabs Remote`, `app_label_root` = `Gabs Remote (Root)`.
  - `namespace 'com.limelight'` **não muda**.
  - Em `strings.xml` (`values` e `values-pt-rBR`), trocar "Moonlight" por "Gabs Remote" só nos textos que o usuário vê com o nome do app; não renomear chaves.
- [ ] **Step 5: Assinatura de release.** Em `build.gradle`, um `signingConfigs { release { ... } }` que lê `keystore.properties` de `System.getenv('GABS_KEYSTORE_PROPS') ?: "${System.getProperty('user.home')}/.gabs-remote/keystore.properties"` (chaves `storeFile`, `storePassword`, `keyAlias`, `keyPassword`) e só é atribuído ao `buildTypes.release` quando o arquivo existe. Em `build-android.ps1`, o switch `-Release` confere o arquivo (código 5 se faltar), roda `assembleNonRootRelease` e, com `-Instalar`, instala esse APK. Acrescentar `keystore.properties` ao `.gitignore` do principal e do submódulo.
- [ ] **Step 6: O Gab cria a keystore** (ele digita as senhas; o Claude só mostra o comando):
  ```
  mkdir $env:USERPROFILE\.gabs-remote
  keytool -genkeypair -v -keystore $env:USERPROFILE\.gabs-remote\gabs-remote-release.jks -alias gabs-remote -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Gabs Remote, O=Gab Tavares, C=BR"
  ```
  e escreve `keystore.properties` na mesma pasta.
- [ ] **Step 7: Backup da keystore fora do repositório**, feito pelo Gab, e registrado em `docs/segredos.md` (só locais e a impressão digital, nunca senhas):
  - **Original:** `%USERPROFILE%\.gabs-remote\` (`gabs-remote-release.jks` + `keystore.properties`).
  - **Backup 1 — nuvem:** a pasta inteira compactada com 7-Zip, AES-256 e cabeçalho cifrado (`7z a -p -mhe=on gabs-remote-segredos.7z %USERPROFILE%\.gabs-remote\*`), no Google Drive do Gab em `Gabs Remote/segredos/`.
  - **Backup 2 — offline:** o mesmo `.7z` num pendrive guardado em casa.
  - **Senhas** (da keystore e do `.7z`): no gerenciador de senhas do Gab, item "Gabs Remote — keystore".
  - **Prova do backup:** extrair o `.7z` do Drive numa pasta temporária, comparar o SHA-256 do `.jks` com o original (`Get-FileHash`) e apagar a pasta temporária. Anotar em `docs/segredos.md` a data do teste e a impressão SHA-256 do certificado (`keytool -list -v -keystore ... | Select-String SHA256`).
  - `docs/segredos.md` também reserva a linha da chave Ed25519 do manifesto (fase 4), que vai para os mesmos três lugares.
- [ ] **Step 8: Verificar.** `build-android.ps1 -Testes` e `build-android.ps1 -Release` passam. `aapt2 dump badging` (do `build-tools;36.0.0`) no APK de release mostra `package: name='com.gabtavares.gabsremote'` e `application-label:'Gabs Remote'`. O Gab desinstala o `Moonlight (Debug)` do tablet, instala o de release, pareia de novo e confere nome e ícone.
- [ ] **Step 9: Commit** — no submódulo `feat(marca): nome, ícone, cores e applicationId do Gabs Remote`; no principal `feat(marca): ícones, segredos e build de release do app`.

### Task 3: Marca Gabs Remote no host

**Files:**
- Modify: `host/tools/sunshinesvc.cpp:25`, `host/src/entry_handler.cpp:146`, `host/src_assets/windows/misc/service/install-service.bat`, `host/src_assets/windows/misc/service/uninstall-service.bat`, `host/src_assets/windows/misc/autostart/autostart-service.bat` (nome do serviço)
- Modify: `host/src/system_tray.cpp` (textos e ícones da bandeja)
- Modify: `host/src_assets/common/assets/web/index.html`, `Navbar.vue`, `sunshine.css` e os ícones em `web/public/` (título, logo, cor primária)
- Create: `tools/marca/servico.Tests.ps1`

**Interfaces:**
- Consumes: `tools/marca/gerar-icones.py --saida-host` e `tools/marca/cores.json` (Task 2).
- Produces: serviço `GabsRemote` (nome exibido `Gabs Remote`), que a Task 4 instala.

- [ ] **Step 1: Escrever o teste Pester que falha** em `tools/marca/servico.Tests.ps1`: nenhum arquivo em `host/src`, `host/tools` e `host/src_assets/windows/misc` contém `SunshineService` (busca com `Select-String -SimpleMatch`), e `install-service.bat` contém `set SERVICE_NAME=GabsRemote`. Rodar: FAIL.
- [ ] **Step 2: Trocar o nome do serviço** para `GabsRemote` nos cinco arquivos, e o `DisplayName` do `sc create` para `Gabs Remote`. O `install-service.bat` ganha também a remoção do serviço antigo `SunshineService`, como ele já faz com o legado `sunshinesvc`. Rodar o teste: PASS.
- [ ] **Step 3: Bandeja e painel.** Gerar os ícones do host com o script da Task 2 e substituir os que `system_tray.cpp` carrega (achar os caminhos pelo `GetResourcePath`/nomes de arquivo usados ali) e os do painel (`web/public/`). Textos da bandeja: "Open Sunshine" → "Abrir Gabs Remote", tooltip "Gabs Remote". Título do painel: "Gabs Remote". Cor primária do painel = a `primaria` de `cores.json` (variável de tema no `sunshine.css`). Os textos da bandeja ficam em pt-BR direto no código; o painel usa os arquivos de locale do upstream, sem renomear chaves.
- [ ] **Step 4: Verificar.** `build-host.ps1 -Testes` sem falha nova (linha de base: 895 rodados, 882 passaram, 13 pulados). Subir em modo console como administrador e conferir bandeja e painel `https://localhost:47990`.
- [ ] **Step 5: Commit** — no submódulo `feat(marca): Gabs Remote na bandeja, no painel e no serviço`; no principal o ponteiro e o teste.

### Task 4: Host como serviço com início automático, e firewall

**Files:**
- Create: `tools/setup/instalar-host.ps1`, `tools/setup/instalar-host.Tests.ps1`
- Modify: `CLAUDE.md` (como instalar/desinstalar o serviço de desenvolvimento)

**Interfaces:**
- Consumes: serviço `GabsRemote` (Task 3); `host/build` compilado.
- Produces: `tools/setup/instalar-host.ps1 [-Desinstalar]` (administrador). Funções exportáveis por dot-source:
  - `Get-RegrasFirewall` → lista de `[pscustomobject]@{Nome; Protocolo; Portas; Perfil; EnderecoRemoto}`
  - `Get-ArgumentosRecuperacao` → `[string[]]` para `sc.exe failure GabsRemote ...`

- [ ] **Step 1: Escrever os testes Pester que falham:**
  - `Get-RegrasFirewall` devolve 4 regras: `Gabs Remote LAN TCP` (47984, 47989, 47990, 48010; perfil `Private`; `EnderecoRemoto` `LocalSubnet`), `Gabs Remote LAN UDP` (47998, 47999, 48000, 48002, 48010, 48100; `Private`; `LocalSubnet`), `Gabs Remote Tailscale TCP` e `Gabs Remote Tailscale UDP` (mesmas portas, perfil `Any`, `EnderecoRemoto` `100.64.0.0/10` e `fd7a:115c:a1e0::/48`).
  - A porta 47990 (painel) **não** aparece nas regras Tailscale (§5.4: painel só local).
  - `Get-ArgumentosRecuperacao` = `@('failure','GabsRemote','reset=','86400','actions=','restart/5000/restart/5000/restart/30000')`.
  Rodar `Invoke-Pester tools/setup/instalar-host.Tests.ps1`: FAIL.
- [ ] **Step 2: Implementar o script.** Instalar: recusa sem administrador (código 1) e de caminho com espaço (código 2); para o serviço se existir; `cmake --install C:\gr\host\build --prefix "C:\Program Files\Gabs Remote"` (o CMake do MSYS2, como no `build-host.ps1`); roda `scripts\install-service.bat` e `scripts\autostart-service.bat` da pasta instalada (conferir os caminhos que o `install()` do `windows.cmake` usa); aplica `Get-ArgumentosRecuperacao`; troca as regras `Gabs Remote (dev)*` pelas de `Get-RegrasFirewall`; inicia o serviço. `-Desinstalar` desfaz tudo e mantém a pasta `config`. Rodar os testes: PASS.
- [ ] **Step 3: O Gab roda como administrador** `powershell -File C:\gr\tools\setup\instalar-host.ps1` e reinicia o PC.
- [ ] **Step 4: Verificar**, anotando no rascunho do checklist da Task 11:
  - Sem fazer login, o tablet acha o PC e abre a sessão **na tela de login do Windows**.
  - Já logado, abrir algo que pede UAC (ex.: `regedit`): o prompt aparece no tablet e aceita toque.
  - `sc.exe qc GabsRemote` mostra `AUTO_START` e `sc.exe qfailure GabsRemote` mostra as três ações de reinício.
  - Matar `sunshine.exe` no Gerenciador de Tarefas: o serviço o sobe de novo em até 5 s.
- [ ] **Step 5: Commit** — `feat(tools): host como serviço GabsRemote e regras de firewall`.

### Task 5: Tela virtual no host

**Files:**
- Create: `host/src/gabs/virtual_display.h`, `host/src/gabs/virtual_display.cpp`
- Create: `host/src/platform/windows/gabs/<driver>_driver.cpp` (`sudovda_driver.cpp` ou `vdd_driver.cpp`, conforme a decisão 0003) e, se o driver tiver header de API, `host/third-party/<driver>/` com o header e a licença dele
- Create: `host/tests/unit/gabs/test_virtual_display.cpp`
- Modify: `host/cmake/compile_definitions/windows.cmake` (fontes novas, junto de `display_wgc.cpp`) e o `common` equivalente para `src/gabs/virtual_display.cpp`
- Modify: `host/src/rtsp.h` (campo em `launch_session_t`), `host/src/nvhttp.cpp:487-500` e `:1415-1425`, `host/src/video.cpp:1510, 3069, 3447`, `host/src/display_device.cpp` (`device_id_from_display_name` e o gancho no revert), `host/src/main.cpp` (instalar o driver real no início)

**Interfaces:**
- Consumes: decisão 0003 (API do driver).
- Produces (todas em `namespace gabs::virtual_display`):
  - `struct mode_t { int width; int height; int refresh_hz; };`
  - `enum class display_choice_e { upstream, mirror, virtual_display };`
  - `display_choice_e parse_display_choice(std::string_view arg);` — `"virtual"` → `virtual_display`, `"mirror"` → `mirror`, qualquer outra coisa (inclusive vazio) → `upstream`.
  - `class driver_t` (abstrata): `bool available()`, `std::optional<std::string> add(const std::string &client_uid, const mode_t &mode)` (devolve o nome GDI `\\.\DISPLAYn`), `bool remove(const std::string &client_uid)`, `void remove_all()`, `void keep_alive()`.
  - `class manager_t`: construtor `manager_t(std::unique_ptr<driver_t> driver, std::function<std::optional<std::string>(const std::string &display_name)> device_id_for)`; `std::optional<std::string> ensure(const std::string &client_uid, const mode_t &mode)` (devolve o device id do libdisplaydevice); `void release_all()`; `void startup_cleanup()`; `std::optional<std::string> active_device_id() const`.
  - `manager_t &instance();` e `void install(std::unique_ptr<manager_t>);` (os testes instalam um manager com driver falso).
  - `std::string effective_output_name(const std::string &configured);` — o device id ativo, se houver, senão `configured`.
  - `std::optional<config::video_t> video_config_for_launch(const config::video_t &base, display_choice_e choice, const std::string &client_uid, const mode_t &mode);` — `upstream` → `base`; `mirror` → `std::nullopt` (não configurar o monitor); `virtual_display` → cópia de `base` com `output_name` = device id, `dd.configuration_option = ensure_only_display`, `dd.resolution_option = automatic`, `dd.refresh_rate_option = automatic`; se `ensure` falhar → loga `warning` e devolve `std::nullopt` (vira espelhar).
  - Em `rtsp_stream::launch_session_t`: `gabs::virtual_display::display_choice_e gr_display;`
  - Em `display_device`: `std::optional<std::string> device_id_from_display_name(const std::string &display_name);` — procura em `enumAvailableDevices()` o dispositivo com esse `m_display_name`, tentando a cada 100 ms por até 3 s (o monitor novo aparece com atraso).

- [ ] **Step 1: Escrever os testes que falham** em `test_virtual_display.cpp`, com um `fake_driver_t` que conta chamadas e pode ser configurado para falhar:
  - `VirtualDisplayLaunch.ParsesDisplayChoice`: `"virtual"`→`virtual_display`, `"mirror"`→`mirror`, `""`→`upstream`, `"VIRTUAL"`→`upstream`.
  - `VirtualDisplayManager.EnsureCreatesOnce`: `ensure("tab", {2800,1752,120})` devolve o device id do `device_id_for` falso; `add` chamado 1 vez; `active_device_id()` igual.
  - `VirtualDisplayManager.EnsureReusesSameClient`: duas chamadas iguais → `add` chamado 1 vez.
  - `VirtualDisplayManager.EnsureRecreatesOnModeChange`: depois `{1400,876,60}` → `remove` 1 vez e `add` 2 vezes.
  - `VirtualDisplayManager.StartupCleanupRemovesAll`: `startup_cleanup()` chama `remove_all` 1 vez e deixa `active_device_id()` vazio.
  - `VirtualDisplayManager.ReleaseAllClearsActive`: depois de `release_all()`, `effective_output_name("cfg") == "cfg"`.
  - `VirtualDisplayLaunch.FallsBackToMirrorWhenDriverFails`: driver com `add` devolvendo `std::nullopt` → `video_config_for_launch(..., virtual_display, ...)` devolve `std::nullopt`; o mesmo quando `device_id_for` devolve `std::nullopt`.
  - `VirtualDisplayLaunch.VirtualOverridesOutputAndDd`: com sucesso, `output_name` é o device id e `dd.configuration_option == ensure_only_display`.
  - `VirtualDisplayLaunch.UpstreamKeepsBase`: `upstream` devolve `base` sem mudança.
- [ ] **Step 2: Rodar e ver falhar.** `build-host.ps1 -Testes`, depois `test_sunshine.exe --gtest_filter=VirtualDisplay*`: não compila/FAIL.
- [ ] **Step 3: Implementar `src/gabs/virtual_display.{h,cpp}`.** `manager_t` guarda `client_uid`, `mode_t` e device id do cliente ativo (um por vez nesta fase; segundo monitor é fase 7), protegido por mutex, e roda uma thread que chama `keep_alive()` a cada 1 s enquanto houver tela ativa (o watchdog do driver remove a tela se o host morrer). Rodar os testes: PASS.
- [ ] **Step 4: Implementar o driver real** em `src/platform/windows/gabs/`, portando do Apollo (`src/platform/windows/virtual_display.cpp`, GPL-3.0) só criar, remover, remover tudo e ping, com o `client_uid` convertido em GUID estável (UUID v5 do uid). Sem driver instalado, `available()` é `false` e `add` devolve `std::nullopt`.
- [ ] **Step 5: Encaixar no upstream** (cada mudança marcada com o comentário `// Gabs Remote:`):
  - `nvhttp.cpp` `make_launch_session`: `launch_session->gr_display = parse_display_choice(get_arg(args, "grDisplay", ""));`
  - `nvhttp.cpp` no `/launch` (linha ~1424): trocar a chamada direta por `video_config_for_launch(config::video, gr_display, unique_id, {width, height, fps})`; com valor, `display_device::configure_display(*valor, *launch_session)`; sem valor, não configurar.
  - `video.cpp` (3 lugares): `display_device::map_output_name(gabs::virtual_display::effective_output_name(config::video.output_name))`.
  - `display_device.cpp`: `device_id_from_display_name`; e, em `try_revert_settings`, quando o revert terminar com sucesso ou não houver nada a reverter, chamar `gabs::virtual_display::instance().release_all()` (assim a tela virtual só sai depois que os monitores físicos voltam).
  - `main.cpp`: logo depois do `display_device::init`, `install(...)` com o driver real e `instance().startup_cleanup()`.
- [ ] **Step 6: Verificar no PC.** `build-host.ps1 -Testes` sem falha nova. Rodar o host em console, abrir sessão no tablet ainda sem o app novo (sem `grDisplay`): comportamento igual ao da fase 1. Simular o app novo com `curl -k` não serve (precisa do certificado do cliente), então a prova de ponta a ponta fica para a Task 6.
- [ ] **Step 7: Commit** — no submódulo `feat(display): tela virtual por cliente (grDisplay)`; no principal o ponteiro.

### Task 6: Perfis de tela e 120 fps no app

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/display/DisplayProfile.java`
- Create: `android/app/src/test/java/com/limelight/gabs/display/DisplayProfileTest.java`
- Modify: `android/app/build.gradle` (`testImplementation 'junit:junit:4.13.2'`, se a Task 2 ainda não pôs)
- Modify: `android/app/src/main/java/com/limelight/preferences/PreferenceConfiguration.java`, `StreamSettings.java`, `android/app/src/main/res/xml/preferences.xml`, `values/strings.xml`, `values-pt-rBR/strings.xml`
- Modify: `android/app/src/main/java/com/limelight/nvstream/http/NvHTTP.java:782` (launch e resume)
- Modify: o ponto onde `Game.java` monta o `StreamConfiguration` (largura, altura, fps)

**Interfaces:**
- Consumes: parâmetro `grDisplay` (Task 5).
- Produces:
  - `enum DisplayProfile { NATIVO, ESPELHAR, FIXO_1080, FIXO_720 }` com `String launchParam()` (`ESPELHAR` → `"mirror"`, os outros → `"virtual"`) e `static int[] resolve(DisplayProfile p, int scalePercent, int nativeWidth, int nativeHeight)` → `{width, height}`.
  - Preferências: `gr_display_profile` (padrão `NATIVO`), `gr_native_scale` (`100`, `67`, `50`; padrão `100`), lidas em `PreferenceConfiguration` como `displayProfile` e `nativeScale`.
  - `StreamConfiguration` (ou o contexto que o `NvHTTP` usa) carrega o `launchParam`, e o `NvHTTP` acrescenta `"&grDisplay=" + param` no `/launch` e no `/resume`.

- [ ] **Step 1: Escrever os testes JUnit que falham** em `DisplayProfileTest`:
  - `resolve(NATIVO, 100, 2800, 1752)` = `{2800, 1752}`; `67` → `{1866, 1168}` (67 significa 2/3 exatos, não 0,67); `50` → `{1400, 876}` (sempre arredonda para baixo até número par).
  - `resolve(NATIVO, 100, 1752, 2800)` (tablet em retrato) = `{2800, 1752}` (usa sempre paisagem).
  - `resolve(FIXO_1080, ...)` = `{1920, 1080}`; `FIXO_720` = `{1280, 720}`; `ESPELHAR` = `{2560, 1440}`.
  - `ESPELHAR.launchParam()` = `"mirror"`; `NATIVO.launchParam()` = `"virtual"`.
  Rodar `build-android.ps1 -Testes`: FAIL.
- [ ] **Step 2: Implementar `DisplayProfile`.** Rodar: PASS.
- [ ] **Step 3: Ligar no app.** Nas configurações de streaming do upstream, duas listas novas ("Perfil de tela": Nativo do tablet, Espelhar monitor, Fixo 1080p, Fixo 720p; "Escala do nativo": 100%, 67%, 50%). A resolução vinda do perfil substitui a da lista de resolução do upstream na hora de montar a sessão; o FPS continua vindo da lista de FPS do upstream (60/90/120). O tamanho nativo vem de `Display.getMode()` (maior lado × menor lado).
- [ ] **Step 4: Verificar no tablet com o host da Task 5** (em console ou serviço):
  - Nativo 100% a 120 fps: no PC aparece só a tela virtual 2800×1752 @ 120 Hz (Configurações > Tela) e o tablet mostra sem barras pretas; ao desconectar, o TCL volta como principal em 2560×1440 @ 180 Hz e os outros monitores como estavam.
  - Nativo 67% e 50%, Fixo 1080p e 720p: a tela virtual tem a resolução pedida.
  - Espelhar: nenhuma tela virtual; o tablet mostra o TCL.
  - Driver desabilitado no Gerenciador de Dispositivos: a sessão Nativo abre mostrando o TCL e o log do host tem o `warning`.
- [ ] **Step 5: Commit** — no submódulo `feat(display): perfis de tela no app`; no principal o ponteiro.

### Task 7: Modos de toque, rejeição de palma, gestos e menu da sessão

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/input/TouchMode.java`, `TouchModePolicy.java`, `LocalZoom.java`, `SessionMenu.java`
- Create: `android/app/src/test/java/com/limelight/gabs/input/TouchModePolicyTest.java`, `LocalZoomTest.java`
- Modify: `android/app/src/main/java/com/limelight/Game.java` (toque, linhas ~2000–2070; caneta ~1665–1745; toque de três dedos), `preferences.xml`, `strings.xml`, `values-pt-rBR/strings.xml`

**Interfaces:**
- Produces:
  - `enum TouchMode { DIRETO, TRACKPAD, SO_CANETA }`; preferência `gr_touch_mode` (padrão `DIRETO`).
  - `class TouchModePolicy`: `void onPenEvent(int actionMasked, long nowMs)`; `boolean penNearby(long nowMs)` (caneta em hover ou contato, ou saiu há menos de `PALM_GRACE_MS = 300`); `Action fingerAction(TouchMode mode, int pointerCount, long nowMs)` com `enum Action { DROP, NATIVE_TOUCH, UPSTREAM_CONTEXT, GESTURE }`.
  - `class LocalZoom`: `void onScale(float factor, float focusX, float focusY)`, `void onPan(float dx, float dy)`, `void reset()`, `float scale()` (limitado a 1,0–4,0), e `float[] translation(int viewWidth, int viewHeight)` sem deixar ver fora da imagem. Aplica no `streamView` com `setScaleX/Y` e `setTranslationX/Y`; o Android já entrega o toque na coordenada local da view escalada.
  - `class SessionMenu`: `PopupMenu` com Teclado, Modo de toque (3 opções com marcação), Redefinir zoom, Medir latência › Clique / Carimbo (ligados na Task 9), Desconectar.

- [ ] **Step 1: Escrever os testes JUnit que falham:**
  - `TouchModePolicyTest`: sem caneta, `fingerAction(DIRETO, 1, t)` = `NATIVE_TOUCH`; `TRACKPAD` = `UPSTREAM_CONTEXT`; `SO_CANETA` com 1 dedo = `DROP`, com 2 dedos = `GESTURE`.
  - Depois de `onPenEvent(ACTION_HOVER_ENTER, 1000)`: `fingerAction(DIRETO, 1, 1100)` = `DROP` (rejeição de palma).
  - Depois de `onPenEvent(ACTION_HOVER_EXIT, 2000)`: em 2299 ainda `DROP`; em 2300 volta a `NATIVE_TOUCH`.
  - Em qualquer modo, 3 dedos = `GESTURE` (o toque de três dedos abre o menu).
  - `LocalZoomTest`: `onScale(10f, …)` limita a 4,0; `onScale(0.1f, …)` limita a 1,0; com escala 1,0 a translação é `{0, 0}`; com escala 2,0 numa view 2800×1752 a translação fica entre −1400 e 1400 em x; `reset()` volta a 1,0.
  Rodar `build-android.ps1 -Testes`: FAIL.
- [ ] **Step 2: Implementar `TouchMode`, `TouchModePolicy`, `LocalZoom`.** Rodar: PASS.
- [ ] **Step 3: Ligar em `Game.java`:**
  - Todo evento de caneta (`TOOL_TYPE_STYLUS`/`ERASER`, inclusive hover) passa por `policy.onPenEvent` antes de ir ao `sendPenEvent`.
  - **DIRETO:** reativar o caminho `trySendTouchEvent` que o upstream comentou, só neste modo, e só quando o host anuncia suporte a toque. Os dois problemas do comentário do upstream: toque cancelado pelo Android (`FLAG_CANCELED` / `ACTION_CANCEL`) manda `LI_TOUCH_EVENT_CANCEL_ALL`; e o toque de três dedos é reconhecido antes, mandando `CANCEL_ALL` para o Windows e abrindo o menu.
  - **TRACKPAD:** o `RelativeTouchContext` do upstream como está (dois dedos rolam, toque de dois dedos é clique direito).
  - **SO_CANETA:** um dedo é ignorado; pinça = `LocalZoom.onScale` (com `ScaleGestureDetector`); dois dedos arrastando = `onPan` se a escala > 1, senão rolagem no PC; toque rápido de dois dedos = clique direito; toque duplo de dois dedos = `reset()`.
  - `DROP` descarta o evento inteiro do dedo (não manda nada ao host).
  - O toque de três dedos, que hoje chama `toggleKeyboard()`, passa a abrir o `SessionMenu`; "Teclado" no menu chama o mesmo `toggleKeyboard()`. A troca de modo pelo menu grava `gr_touch_mode` e vale na hora.
- [ ] **Step 4: Verificar no tablet:** no modo Direto, arrastar uma janela com o dedo e fazer pinça no Paint 3D/navegador (zoom do Windows); no Trackpad, cursor relativo, rolagem e clique direito; no Só caneta, desenhar com a mão apoiada na tela sem traço de palma, pinça aproxima a imagem só no tablet e o toque duplo de dois dedos volta.
- [ ] **Step 5: Commit** — no submódulo `feat(input): modos de toque, rejeição de palma, zoom local e menu da sessão`; no principal o ponteiro.

### Task 8: S Pen completa e teclado com todos os atalhos

**Files:**
- Create: `docs/testes/fase-2-entrada.md` (matriz de teste)
- Modify (só se a matriz mostrar falha): `android/app/src/main/java/com/limelight/Game.java` (`sendPenEventForPointer` ~1665, teclas ~1190–1310), `android/app/src/main/java/com/limelight/binding/input/KeyboardTranslator.java`, `host/src/platform/virtualhid_input.cpp:997-1070` (`pen_update`)

**Interfaces:**
- Consumes: `TouchModePolicy` (Task 7).
- Produces: a matriz preenchida, que a Task 11 copia para o checklist.

O caminho da caneta já existe ponta a ponta: o app manda `sendPenEvent` com pressão, inclinação (`AXIS_TILT`), rotação, hover e botões, e o host injeta como caneta do Windows pela API `InjectSyntheticPointerInput` (libvirtualhid, sem licença paga; a licença só vale para gamepad/teclado/mouse por driver). Esta tarefa prova cada item e corrige o que falhar.

- [ ] **Step 1: Escrever a matriz** `docs/testes/fase-2-entrada.md`, uma linha por item, com colunas Photoshop / Illustrator / Figma (navegador) / Windows Ink (área de esboço):
  - caneta: pressão (traço fino→grosso), inclinação (pincel que responde à inclinação), hover (cursor do pincel acompanha sem tocar), botão lateral (clique direito ou a função configurada), rejeição de palma.
  - teclado físico (Book Cover) e Bluetooth: Ctrl+C/V/Z, Ctrl+Shift+Esc, Alt+Tab (segurando Alt e passando com Tab), Alt+F4, Win, Win+D, Win+Shift+S, F1–F12, Esc, setas, Print Screen.
- [ ] **Step 2: O Gab testa** com a matriz no Nativo 120 fps, e o Claude registra o resultado (✓/✗ e o que acontece).
- [ ] **Step 3: Para cada ✗, corrigir com teste antes:**
  - Se a falha estiver na conversão do app (ex.: inclinação em graus errada, botão não mapeado, tecla com código errado), escrever um teste JUnit da conversão extraída para `com.limelight.gabs.input` (ex.: `PenMapping.tiltDegrees(float axisTiltRad)`, `KeyMapping.toWindowsVk(int androidKeyCode)`), ver falhar, corrigir, ver passar.
  - Se o Android engolir a tecla antes do app (Alt+Tab, Win), conferir que a captura de tecla Meta da Samsung (`requestMetaKeyEvent`, `Game.java:694`) está ligada para o teclado em uso, e que a sessão pede captura de teclas do sistema; anotar o que o One UI não deixa capturar e oferecer o atalho equivalente no `SessionMenu` (item "Alt+Tab" e "Win").
  - Se a falha for no host (ex.: hover não move o cursor), escrever teste GoogleTest em `host/tests/unit/gabs/` sobre a conversão em `pen_update` e corrigir.
- [ ] **Step 4: Repetir a matriz** até tudo ✓ ou com limitação aceita pelo Gab e escrita na matriz.
- [ ] **Step 5: Commit** — `fix(input): ...` em cada submódulo que mudou; no principal `docs: matriz de entrada da fase 2`.

### Task 9: Medidor de latência (§9.3)

**Files:**
- Create: `tools/latencia/Marcador/Marcador.csproj` (`net8.0-windows`, WinForms), `Program.cs`, `MarcadorForm.cs`, `StampCodec.cs`, `RelogioUdp.cs`
- Create: `tools/latencia/Marcador.Tests/Marcador.Tests.csproj` (xUnit), `StampCodecTests.cs`
- Create: `android/app/src/main/java/com/limelight/gabs/latency/StampCodec.java`, `ClockSync.java`, `LatencyStats.java`, `LatencyProbe.java`
- Create: `android/app/src/test/java/com/limelight/gabs/latency/StampCodecTest.java`, `ClockSyncTest.java`, `LatencyStatsTest.java`
- Create: `docs/latencia.md` (como medir)
- Modify: `SessionMenu.java` (itens "Medir latência")

**Interfaces:**
- **Contrato do carimbo** (igual nos dois lados): janela de 192×80 px no canto superior esquerdo do monitor principal, sempre por cima, sem borda.
  - Área de carimbo (x 0–127): grade de 8 colunas × 5 linhas, células de 16×16 px. Linha 0 = calibração (colunas pares brancas, ímpares pretas). Linhas 1–4 = 32 bits de `t` (milissegundos desde o início do marcador, `uint32`), do bit mais alto para o mais baixo, linha a linha; bit 1 = branco.
  - Área de clique (x 128–191, y 0–63): quadrado que alterna preto/branco a cada F24 (`VK_F24 = 0x87`) recebido por `RegisterHotKey`.
  - Relógio: UDP 48100 no PC. Pedido de 1 byte `0x01`; resposta de 8 bytes, `int64` little-endian com os mesmos milissegundos de `t`.
- C#: `static bool[] StampCodec.Encode(uint t)` (40 células: 8 de calibração + 32 de dados).
- Java:
  - `static Long StampCodec.decode(int[] cellLuma)` (40 lumas na mesma ordem; `null` se brancos − pretos da calibração < 64; limiar = média das duas médias).
  - `static long ClockSync.offsetMs(long[] t0, long[] hostMs, long[] t1)` (usa a amostra de menor `t1 − t0`; offset = `hostMs − (t0 + t1) / 2`).
  - `LatencyStats.add(double ms)`, `addLost()`, `double avg()`, `double p50()`, `double p95()`, `double max()`, `int lost()`, `String toCsv(String mode)`.
  - `LatencyProbe`: lê a região com `PixelCopy` do `SurfaceView` da sessão, uma vez por quadro (`Choreographer`).

- [ ] **Step 1: Testes que falham, dos dois lados, com o mesmo vetor:**
  - C# `StampCodecTests`: `Encode(0x89ABCDEF)` tem a calibração `B,P,B,P,B,P,B,P` e as 32 células de dados `10001001 10101011 11001101 11101111`; `Encode(0)` tem as 32 de dados pretas.
  - Java `StampCodecTest`: lumas montadas desse mesmo padrão (branco 235, preto 16) → `decode` = `0x89ABCDEFL`; com ruído de ±40 em cada célula → mesmo valor; calibração com diferença 50 → `null`.
  - `ClockSyncTest`: amostras `(t0, host, t1)` = `(0, 1000, 20)`, `(100, 1090, 104)`, `(200, 1200, 260)` → offset `988` (a de RTT 4).
  - `LatencyStatsTest`: de 1 a 100 ms → avg 50,5, p50 50, p95 95, max 100; `addLost()` duas vezes → `lost() == 2`; `toCsv("clique")` começa com `modo,amostra,ms`.
  Rodar `dotnet test tools/latencia/Marcador.Tests` e `build-android.ps1 -Testes`: FAIL.
- [ ] **Step 2: Implementar os codecs, `ClockSync` e `LatencyStats`.** Rodar: PASS.
- [ ] **Step 3: Implementar o marcador.** `MarcadorForm` redesenha o carimbo a cada quadro do monitor (laço com `DwmFlush` numa thread, `Invalidate` na UI); `RelogioUdp` responde em 48100; `Program` aceita `--monitor <n>` (padrão: principal). Publicar com `dotnet publish -c Release -r win-x64 --self-contained false -o tools\latencia\bin` (pasta ignorada pelo git).
- [ ] **Step 4: Implementar `LatencyProbe` e os itens do menu.**
  - **Clique:** 40 amostras a cada 400 ms. Cada uma manda F24 (descer/subir) pelo caminho de teclado do upstream, guarda `t0` e lê a luma média da área de clique a cada quadro; a amostra termina quando a luma cruza 128 no sentido esperado (latência = agora − `t0`) ou em 1000 ms (`addLost`).
  - **Carimbo:** sincroniza o relógio com 20 pings UDP ao endereço do PC da sessão, depois decodifica o carimbo a cada quadro por 10 s; latência = (agora + offset) − `t`.
  - Fim: diálogo com média, p50, p95, máx e perdidos, e CSV em `getExternalFilesDir(null)/latencia-AAAAMMDD-HHmm.csv`.
  - A latência do carimbo inclui o tempo do `PixelCopy`; anotar isso no `docs/latencia.md`.
- [ ] **Step 5: Verificar** em casa, no Nativo 120 fps: as duas medidas saem sem perdidos acima de 5% e com valores entre 5 e 200 ms. `docs/latencia.md` explica como rodar o marcador, onde ficam os CSVs (`adb pull /sdcard/Android/data/com.gabtavares.gabsremote/files/`) e o que cada modo mede.
- [ ] **Step 6: Commit** — no principal `feat(tools): marcador do medidor de latência`; no submódulo `feat(latency): medidor de latência no app`; no principal o ponteiro.

### Task 10: Acesso de fora pelo Tailscale

**Files:**
- Create: `docs/tailscale.md`

**Interfaces:**
- Consumes: regras `Gabs Remote Tailscale *` (Task 4), app de release (Task 2).
- Produces: o PC acessível do tablet pelo nome MagicDNS (ex.: `pc-do-gab`). A escolha automática entre IPv6, port forward e Tailscale fica para a fase 3.

O host já trata `100.64.0.0/10` como LAN (`host/src/network.cpp:33`), então pareamento e sessão funcionam pelo Tailscale sem mudança no código.

- [ ] **Step 1: O Gab instala o Tailscale** no PC (`winget install Tailscale.Tailscale`) e no tablet (Play Store), entra com a mesma conta nos dois. No PC: ativar "Run unattended" (funciona antes do login) e, no painel do Tailscale, desativar a expiração da chave do PC ("Disable key expiry"). Anotar o nome MagicDNS e o IP `100.x` do PC.
- [ ] **Step 2: Conferir no PC** que `Get-NetConnectionProfile` lista a interface do Tailscale e que as regras Tailscale valem nela (perfil `Any` com endereço remoto restrito), e que `Test-NetConnection <ip-100.x> -Port 47989` responde de outro aparelho da tailnet.
- [ ] **Step 3: No tablet, no 4G/5G com o Wi-Fi desligado:** adicionar o PC manualmente pelo nome MagicDNS no app (o PC já pareado em casa aparece como o mesmo, pelo id). Abrir sessão Nativo a 60 e 120 fps com bitrate de 20, 35 e 50 Mbps, e anotar no rascunho do checklist: se o Tailscale está em conexão direta ou via DERP (`tailscale status` no PC), latência de rede do overlay, quadros perdidos, e uma medida de clique-até-imagem.
- [ ] **Step 4: Escrever `docs/tailscale.md`** (instalação, configurações acima, como saber se está direto ou por DERP, o que fazer se cair) e fazer commit — `docs: acesso de fora pelo Tailscale`.

### Task 11: Medição da fase, checklist e fechamento

**Files:**
- Create: `docs/testes/fase-2-checklist.md`
- Modify: `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§6.1: resultado do 4:4:4; §11: riscos resolvidos)
- Modify: `docs/sessoes.md`, `CLAUDE.md` (onde ficam os módulos `gabs/` nos forks), `graphify-out/`

- [ ] **Step 1: 4:4:4 no Tab S10+.** No app, listar pelo `MediaCodecList` se algum decodificador HEVC/AV1 anuncia perfil 4:4:4 (`HEVCProfileMain444` ou `AV1ProfileMain` com 4:4:4) e anotar. Se não houver, a spec fica com HEVC 4:2:0 de bitrate alto e o modo texto 4:4:4 sai do escopo.
- [ ] **Step 2: Medir com a tela em movimento** (vídeo em tela cheia ou janela sendo arrastada), corrigindo a observação da fase 1: em casa, Nativo 100% a 60, 90 e 120 fps; Espelhar a 60 fps. Para cada um: FPS recebidos/renderizados, decodificador, tempo de decodificação, processamento no host, latência de rede, e o medidor (clique e carimbo: média, p95, perdidos). Mesma medida no 4G/5G pelo Tailscale (Task 10).
- [ ] **Step 3: Escrever `docs/testes/fase-2-checklist.md`** com os critérios da spec para a fase 2, cada um ✓/✗ com a evidência:
  - Critério 2 (imagem): texto nítido no VS Code e no Figma com a tela rolando; 60/90/120 escolhíveis.
  - Critério 3 (resolução): Nativo sem barras pretas; perfis 1080p/720p; resolução original restaurada ao desconectar **e** depois de matar o host no meio da sessão (Review Focus 2).
  - Critério 4 (entrada): matriz da Task 8.
  - Critério 6 (disponibilidade, parte da fase 2): sessão na tela de login e no UAC; serviço volta sozinho (Task 4). WoL e reconexão automática são da fase 3.
  - Tailscale: sessão no 4G/5G funcionando, com os números.
  - Parsec/SuperDisplay ativos durante a sessão: qual saída o host usa no Espelhar (pendência da fase 1).
  - Linha de base para a fase 3: latência clique-até-imagem em casa e fora.
- [ ] **Step 4: Atualizar o grafo** (`/graphify . --update`), o `CLAUDE.md` (pastas `host/src/gabs/`, `host/src/platform/windows/gabs/`, `android/.../com/limelight/gabs/`, `tools/latencia/`, `tools/marca/`, `tools/setup/instalar-host.ps1`) e `docs/sessoes.md` (fase 2 feita; prompt da fase 3).
- [ ] **Step 5: Commit** — `docs: checklist e fechamento da fase 2`. Push dos submódulos e do principal só com o ok do Gab.

---

## Próxima sessão

Para **executar este plano**, comece uma sessão nova e use:

> Gabs Remote — executar o plano `docs/superpowers/plans/2026-11-07-fase-2-streaming.md`. Leia o `CLAUDE.md`, o plano e as decisões em `docs/decisoes/`. Execução nativa (executing-plans), pedindo meu ok nos passos marcados (cores, instalar driver/serviço/firewall, keystore, push). Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

Se a execução parar no meio:

> Gabs Remote — continuar a execução de `docs/superpowers/plans/2026-11-07-fase-2-streaming.md`. Leia o `CLAUDE.md`, confira no `git log` (principal e submódulos) e nos checkboxes o que já foi feito e siga da próxima tarefa.

Depois da fase 2 executada, o plano da **fase 3 (Fora de casa completo)** usa:

> Gabs Remote — escrever o plano da **fase 3 (Fora de casa completo)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§5, §5.3, §5.4, §7, §10, §11), `docs/decisoes/`, `docs/testes/fase-2-checklist.md` (linha de base de latência em casa e fora), `docs/tailscale.md` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks a descoberta de endereços, a reconexão e o pareamento. Escreva o plano com a skill writing-plans, terminando com a seção "Próxima sessão".
