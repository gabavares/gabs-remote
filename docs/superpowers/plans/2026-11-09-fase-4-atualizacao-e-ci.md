# Fase 4 — Atualização e CI: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar uma Release no `gabavares/gabs-remote` faz o host e o app oferecerem a nova versão com as notas e se atualizarem sem reinstalar à mão (critério 7), com manifesto assinado por Ed25519, instalador Windows próprio e CI no GitHub Actions; no fim, uma rodada de testes em lote cobre o que ficou pendente da fase 3 e a fase 4.

**Architecture:** Um arquivo `versao.json` na raiz do principal é a única fonte da versão do sistema (`x.y.z`) e das versões mínimas compatíveis; os scripts de build passam esses valores ao CMake (`BUILD_VERSION`) e ao Gradle (`-PgabsVersion`). O CI do principal compila host e APK **sem segredos** e cria o rascunho da Release; no PC do Gab, `preparar-release.ps1` assina o APK com a keystore, monta o `manifest.json` com os SHA-256, assina com a chave Ed25519 (OpenSSL) e sobe tudo para o rascunho; publicar é o clique do Gab. O updater do host fica **dentro do host** (C++: já tem curl, OpenSSL, bandeja, contagem de sessões e o painel): confere ao iniciar e a cada 24 h, baixa para `config\updates`, confere hash e assinatura e, sem sessão, roda o instalador NSIS em silêncio fora do job object do serviço. O app ganha `gabs/update/` (OkHttp + BouncyCastle + `PackageInstaller`) e um aviso de compatibilidade antes de conectar, a partir da versão que o host passa a informar no `/serverinfo`.

**Tech Stack:** C++23 + GoogleTest + OpenSSL 3 + libcurl (host, MSYS2 UCRT64), Vue 3 (painel), NSIS 3 do MSYS2 (instalador), Java 17 + JUnit 4 + BouncyCastle + OkHttp (app), PowerShell 5.1 + Pester 5 + OpenSSL do Git for Windows + `gh` + `apksigner` (ferramenta de release), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§1.1 critério 7, §4.1 H6/H7/A5, §8 Atualização automática, §9.1, §9.2, §10 linha da fase 4). Decisões: `docs/decisoes/0002-marca-e-application-id.md` (o `applicationId` `com.gabtavares.gabsremote` não muda), `docs/decisoes/0005-fora-de-casa.md` (nenhuma porta do host para a internet). Segredos: `docs/segredos.md`. Pendências da fase 3: `docs/testes/fase-3-checklist.md`.

## Decisões deste plano (o Gab confirma ao revisar; viram a decisão 0006 na Task 1)
1. **Assinaturas só no PC do Gab.** O CI não recebe a keystore nem a chave Ed25519 (nem como *secret* do GitHub): ele gera o instalador e um APK **sem assinatura**; `preparar-release.ps1` assina localmente. Quem tomar a conta do GitHub não consegue publicar uma atualização que os updaters aceitem.
2. **Versão única do sistema** `x.y.z` (host, app e Release iguais), começando em **0.4.0** (fase 4). Tag `vx.y.z`. `versionCode` do APK = `major·1 000 000 + minor·1 000 + patch` (0.4.0 → 4000, maior que o 315 do upstream instalado hoje); cada parte vai de 0 a 999.
3. **O updater do host vive no host** (`host/src/gabs/update*`), não num executável à parte (spec H7): reaproveita curl, OpenSSL, bandeja, painel e `rtsp_stream::session_count()`. O instalador sai do job object do `sunshinesvc` por `CREATE_BREAKAWAY_FROM_JOB` (o job já tem `JOB_OBJECT_LIMIT_BREAKAWAY_OK`).
4. **A configuração continua em `C:\Program Files\Gabs Remote\config`** (como desde a fase 2; o instalador nunca toca nela), e não em `%ProgramData%` (spec §8). Os downloads vão para `config\updates\`, que só administradores e SYSTEM podem gravar.
5. **Instalador NSIS próprio** em `installer/` (não o WiX/cpack do upstream, que cria o serviço e as regras de firewall do Sunshine). As regras continuam as da fase 3: só LAN e Tailscale.
6. Os workflows do upstream nos forks ficam como estão e **desligados** (Actions não habilitadas nos forks); todo o CI do Gabs Remote fica no principal.

## Global Constraints
- Docs, notas de versão, UI e mensagens ao Gab em **pt-BR**; código e identificadores em inglês. Toda mudança em arquivo do upstream leva o comentário `// Gabs Remote:` (ou `<!-- Gabs Remote: -->` em Vue/XML).
- **Todo build roda por `C:\gr`.** Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Testes] [-Jobs 8]`, nunca mais de 8 jobs. App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Release] [-Instalar]`. Testes do host: `C:\gr\host\build\tests\test_sunshine.exe --gtest_filter=<Suite>.*`.
- Scripts `.ps1` em UTF-8 **com BOM**. Testes Pester ao lado do script (`*.Tests.ps1`).
- Com o serviço `GabsRemote` rodando, pare-o antes de testar o `sunshine.exe` do build em console.
- `applicationId` `com.gabtavares.gabsremote` (decisão 0002) e alias da keystore `gabs-remote`; impressão SHA-256 do certificado: `17:0F:8C:18:2D:A2:84:C1:01:2F:35:42:5E:40:45:FF:C7:AD:4E:C6:C9:8F:48:5B:FF:94:9A:7C:8F:26:7F:49`.
- Repositório da Release: `gabavares/gabs-remote` (público). Manifesto em `https://github.com/gabavares/gabs-remote/releases/latest/download/manifest.json` e `.../manifest.json.sig`; artefatos em `https://github.com/gabavares/gabs-remote/releases/download/v<versão>/<arquivo>`. Nomes: `GabsRemote-Setup-<versão>.exe`, `GabsRemote-<versão>.apk`.
- Só HTTPS, com redirecionamento só para HTTPS. Nada de porta nova de entrada (decisão 0005); o painel (47990) continua só local.
- **Commit, push, tag, Release (rascunho e publicação) e habilitar Actions no Gabs Remote: o Claude faz quando precisar, sem pedir** (Gab, 09/11/2026). Pede o ok só se a ação afetar outro projeto do Gab (site `gabtavares.com`, hospedagem, Vagabs, executor do Claude, outros repositórios). Senhas (keystore, chave Ed25519) o Gab digita; instalar o serviço/instalador e regra de firewall: o Gab roda como administrador.
- Segredos (keystore, senhas, chave privada Ed25519) **nunca** no repositório, na conversa nem em *secret* do GitHub. A senha da chave Ed25519 o Gab digita no terminal. A chave de **teste** em `tools/release/testdata/` é pública por definição e tem esse nome.
- Interface nova no app só com componentes padrão do Android (`AlertDialog`, `Toast`, preferências do upstream); layout próprio é da fase 7. No painel, o visual atual (marca da fase 2).
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>` e `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Submódulo primeiro, depois o principal com o ponteiro.

## Formato do manifesto (todas as tasks usam este)
`manifest.json` em UTF-8 sem BOM, `manifest.json.sig` = os 64 bytes crus da assinatura Ed25519 sobre os bytes exatos do `manifest.json`.
```json
{
  "schema": 1,
  "version": "0.4.1",
  "date": "2026-11-20",
  "notes": "texto em pt-BR, Markdown simples",
  "host": { "file": "GabsRemote-Setup-0.4.1.exe", "sha256": "<64 hex minúsculos>", "size": 12345678, "minApp": "0.4.0" },
  "app":  { "file": "GabsRemote-0.4.1.apk", "sha256": "<64 hex minúsculos>", "size": 23456789, "versionCode": 4001, "minHost": "0.4.0" }
}
```
Regras de validação (iguais no host, no app e na ferramenta): `schema == 1`; versões `^\d{1,3}\.\d{1,3}\.\d{1,3}$`; `file` em `^[A-Za-z0-9._-]+$` sem `..`; `sha256` com 64 hex minúsculos; `size > 0`; `versionCode` igual ao calculado de `version`. Qualquer falha = manifesto inválido (nada é baixado).

## Review Focus
1. **Manifesto adulterado, assinado com outra chave ou mais antigo que o instalado** (ataque de troca ou de volta de versão). Esperado: nada é baixado nem instalado, o painel e o app dizem "Atualização inválida" ou "Em dia". Testes `UpdateManifest.RejectsTamperedManifest`, `UpdateManifest.RejectsOtherKey`, `UpdatePolicy.IgnoresOlderOrEqualVersion` (Task 4) e `ManifestVerifierTest.rejectsTampered`, `UpdateCheckerTest.ignoresOlderOrEqual` (Task 7).
2. **Atualização chegando com sessão ativa ou com o PC "pronto" (app em segundo plano, decisão 0004).** Esperado: o host baixa, avisa na bandeja e espera; instala só com 0 sessões e nenhum app rodando. Teste `UpdatePolicy.WaitsWhileSessionOrAppRunning` (Task 4); item manual na Task 11.
3. **Download interrompido ou arquivo trocado entre a conferência e a execução.** Esperado: arquivo parcial (`.part`) nunca é executado; o hash é conferido de novo logo antes de rodar; a pasta `config\updates` não é gravável por usuário comum. Teste `UpdateFiles.PartialFileNeverReady` (Task 5); conferência do ACL na Task 6.
4. **Primeira instalação pelo instalador sobre a instalação manual da fase 2/3** (`instalar-host.ps1`). Esperado: pareamentos, login do painel e `sunshine.conf` preservados; serviço `GabsRemote` com início automático e recuperação; só as regras `Gabs Remote LAN *` e `Gabs Remote Tailscale *`. Testes `configurar-host.Tests.ps1` "nenhuma regra sem RemoteAddress restrito" e "não toca em config" (Task 6); item manual na Task 10.
5. **App e host em versões incompatíveis** (um atualizou, o outro não; ou host antigo sem `GabsVersion`). Esperado: com host sem o campo, conecta como hoje; com incompatibilidade, diálogo claro antes de conectar com "Atualizar o app" ou "Conectar mesmo assim". Testes `CompatTest` (Task 8).

---

### Task 1: Decisão 0006 e chave Ed25519 do manifesto

**Files:**
- Create: `docs/decisoes/0006-atualizacao-e-release.md`
- Modify: `docs/segredos.md` (seção "Chave Ed25519 do manifesto"), spec §8 (configuração em `Program Files\Gabs Remote\config`; updater do host dentro do host; assinatura só local; versão 0.4.0), §4.1 linha H7

**Interfaces:**
- Produces: a chave pública Ed25519 de produção em base64 (32 bytes crus), anotada em `docs/segredos.md`, que as Tasks 4 e 7 embutem como `kPublicKeyBase64` / `UpdateKey.PUBLIC_KEY_BASE64`.

- [ ] **Step 1: Escrever a decisão 0006** com as seis decisões do topo deste plano (contexto, decisão, consequências: o CI nunca publica nada sozinho; perder a chave Ed25519 = os updaters param de aceitar versões novas e é preciso reinstalar à mão host e app com uma chave nova embutida). Ajustar a spec §8 e §4.1 H7 citando a 0006.
- [ ] **Step 2: O Gab cria a chave** (ele digita a senha; o Claude não vê) e faz os backups como os da keystore:
  ```powershell
  & 'C:\Program Files\Git\usr\bin\openssl.exe' genpkey -algorithm ed25519 -aes-256-cbc -out $env:USERPROFILE\.gabs-remote\manifesto-ed25519.pem
  ```
  Pública em base64 (sem senha para sair): `openssl pkey -in <pem> -pubout -outform DER` e os últimos 32 bytes em base64 (o `preparar-release.ps1` da Task 2 terá `Get-ChavePublica` para isso; aqui basta rodar à mão e anotar).
- [ ] **Step 3: Atualizar `docs/segredos.md`**: tabela de cópias da chave (original, `.7z` no Drive, pendrive, senha no gerenciador como "Gabs Remote — chave do manifesto"), data, chave **pública** em base64 e SHA-256 do `.pem`. Incluir no `.7z` de backup a keystore e a chave juntas.
- [ ] **Step 4: Commit** — `docs: decisão 0006 (atualização e release) e chave do manifesto`.

### Task 2: `versao.json` e ferramenta de release

**Files:**
- Create: `versao.json` (`{"version": "0.4.0", "minApp": "0.4.0", "minHost": "0.4.0"}`)
- Create: `tools/release/Release.psm1`, `tools/release/Release.Tests.ps1`, `tools/release/preparar-release.ps1`, `tools/release/gerar-fixture.ps1`
- Create: `tools/release/testdata/` (`chave-de-teste.pem` sem senha, `chave-de-teste.pub.b64`, `manifest.json`, `manifest.json.sig`, `manifest-adulterado.json`, `manifest-outra-chave.json.sig`)
- Create: `docs/notas/0.4.0.md` (notas da primeira versão, pt-BR)

**Interfaces:**
- Produces (funções exportadas de `Release.psm1`):
  - `Get-VersaoGabs [-Arquivo <caminho>]` → `[pscustomobject]@{ Version; MinApp; MinHost }`; lança erro se alguma versão não casar com `^\d{1,3}\.\d{1,3}\.\d{1,3}$`.
  - `Get-VersionCode -Versao '0.4.1'` → `[int] 4001`.
  - `New-Manifesto -Versao -Data -Notas -Instalador <caminho> -Apk <caminho> -MinApp -MinHost` → string JSON no formato acima (campos nessa ordem, `\n`, sem BOM).
  - `Test-Manifesto -Json <string>` → `$true`/`$false` pelas regras de validação.
  - `Invoke-AssinarManifesto -Manifesto <caminho> -Chave <pem>` (chama `openssl pkeyutl -sign -rawin`; a senha o OpenSSL pede no terminal) e `Test-AssinaturaManifesto -Manifesto -Assinatura -ChavePublicaBase64` → bool.
  - `Get-ChavePublica -Chave <pem>` → base64 dos 32 bytes.
- Produces: os arquivos de `testdata/` que as Tasks 4 e 7 copiam para os testes dos submódulos.

- [ ] **Step 1: Testes que falham** em `Release.Tests.ps1`: `Get-VersaoGabs` lê o `versao.json` e recusa `"v0.4"` e `"1.2.3-beta"`; `Get-VersionCode '0.4.0'` = 4000 e `'1.2.3'` = 1002003; `New-Manifesto` com dois arquivos temporários de conteúdo conhecido gera os SHA-256 e tamanhos certos e `versionCode` 4001 para 0.4.1; `Test-Manifesto` recusa `file` com `..\x.exe`, `sha256` maiúsculo e `schema` 2; assinar com `chave-de-teste.pem` e conferir com `chave-de-teste.pub.b64` dá `$true`, e com `manifest-adulterado.json` dá `$false`. Rodar `Invoke-Pester C:\gr\tools\release\Release.Tests.ps1`: FAIL.
- [ ] **Step 2: `gerar-fixture.ps1`** gera a chave de teste, o manifesto de teste (versão `0.4.1`, hashes de arquivos fictícios), a assinatura, o adulterado (troca um dígito do `sha256` do host) e uma assinatura feita com uma segunda chave descartada. Rodar uma vez e commitar o resultado (os bytes ficam fixos; os testes dos três lados usam os mesmos).
- [ ] **Step 3: Implementar `Release.psm1`.** OpenSSL: `C:\Program Files\Git\usr\bin\openssl.exe` (mensagem clara se faltar). Rodar os testes: PASS.
- [ ] **Step 4: `preparar-release.ps1 -Versao 0.4.0 [-Enviar]`**, na ordem: confere que `versao.json` diz a mesma versão e que existe `docs/notas/<versão>.md`; `gh release download v<versão>` do rascunho para uma pasta temporária (`GabsRemote-Setup-<v>.exe` e `GabsRemote-<v>-unsigned.apk`); `zipalign -p -f 4` e `apksigner sign` com os dados do `keystore.properties` (senha por variável de ambiente do processo, `--ks-pass env:…`, apagada no fim); `apksigner verify --print-certs` e comparação com a impressão SHA-256 das Global Constraints (diferente = para); `New-Manifesto`, `Invoke-AssinarManifesto`, `Test-AssinaturaManifesto` com a pública de `docs/segredos.md`; mostra o resumo (versão, hashes, tamanhos). Só com `-Enviar`: `gh release upload v<v> GabsRemote-<v>.apk manifest.json manifest.json.sig --clobber` e `gh release delete-asset v<v> GabsRemote-<v>-unsigned.apk -y`, e imprime o link do rascunho para o Gab publicar.
- [ ] **Step 5: Commit** — `feat(release): versao.json, manifesto assinado e preparar-release`.

### Task 3: A versão nos builds e no `/serverinfo`

**Files:**
- Modify: `tools/build/build-host.ps1`, `tools/build/build-android.ps1` (importam `tools/release/Release.psm1`)
- Modify: `host/cmake/compile_definitions/common.cmake` (define `GABS_MIN_APP`), `host/src/nvhttp.cpp:1271` (perto de `root.appversion`)
- Modify: `android/app/build.gradle` (`versionName`, `versionCode`, `buildConfigField`), `android/app/src/main/java/com/limelight/nvstream/http/NvHTTP.java:374` (junto do `mac`), `ComputerDetails.java` (campos e `update()`)

**Interfaces:**
- Consumes: `Get-VersaoGabs`, `Get-VersionCode` (Task 2).
- Produces:
  - Host: `PROJECT_VERSION` = versão do `versao.json` (o `build-host.ps1` exporta `BUILD_VERSION=<versão>` e `BRANCH=main`, que o `cmake/prep/build_version.cmake` já aceita) e o define `GABS_MIN_APP` (`-DGABS_MIN_APP=<minApp>`, padrão `"0.0.0"`). `/serverinfo` ganha `root.GabsVersion` = `PROJECT_VERSION` e `root.GabsMinApp` = `GABS_MIN_APP`.
  - App: `-PgabsVersion=<v> -PgabsMinHost=<minHost>`; `versionName` = `<v>`, `versionCode` pela fórmula da decisão 2 (sem a propriedade: `0.0.0`, `versionCode 1`, e o `assemble*Release` falha com "passe -PgabsVersion (use build-android.ps1)"); `BuildConfig.GABS_MIN_HOST` (String). `ComputerDetails.gabsVersion` e `ComputerDetails.gabsMinApp` (String, `null` em host antigo), copiados em `update()`.

- [ ] **Step 1: Testes Pester** que falham, em `tools/release/Release.Tests.ps1`: as funções novas de `Release.psm1` `Get-ArgumentosVersaoHost -Versao <obj>` → `@{ Env = @{ BUILD_VERSION = '0.4.0'; BRANCH = 'main' }; CMake = @('-DGABS_MIN_APP=0.4.0') }` e `Get-ArgumentosVersaoApp -Versao <obj>` → `@('-PgabsVersion=0.4.0', '-PgabsMinHost=0.4.0')`, para o `versao.json` de teste. Rodar: FAIL.
- [ ] **Step 2: Implementar** as duas funções e o uso nos scripts; o Gradle e o CMake como descrito. Rodar os testes Pester: PASS.
- [ ] **Step 3: Verificar o host:** `build-host.ps1`; no log do `sunshine.exe` em console, `Sunshine version: 0.4.0`; `curl.exe http://localhost:47989/serverinfo` (host em console, no próprio PC) mostra `<GabsVersion>0.4.0</GabsVersion>` e `<GabsMinApp>0.4.0</GabsMinApp>`.
- [ ] **Step 4: Verificar o app:** `build-android.ps1 -Release`; `apkanalyzer manifest version-code <apk>` = 4000 e `version-name` = 0.4.0. `build-android.ps1 -Testes`: tudo passa.
- [ ] **Step 5: Commit** — host `feat(gabs): versão do Gabs Remote no serverinfo`; app `feat(gabs): versão do Gabs Remote no build e no ComputerDetails`; principal `feat(build): versão única do versao.json` com os ponteiros.

### Task 4: Host — manifesto, assinatura e política de atualização

**Files:**
- Create: `host/src/gabs/update_manifest.h`, `host/src/gabs/update_manifest.cpp`, `host/src/gabs/update_key.h`, `host/src/gabs/update_policy.h`, `host/src/gabs/update_policy.cpp`
- Create: `host/tests/unit/gabs/test_update.cpp`, `host/tests/unit/gabs/testdata/update/` (cópia do `tools/release/testdata/`, sem o `.pem`)
- Modify: `host/cmake/compile_definitions/common.cmake` (junto de `src/gabs/presence.cpp`), `host/tests/CMakeLists.txt` se os testes `gabs` precisarem dos arquivos de dados copiados

**Interfaces:**
- Produces (em `namespace gabs::update`):
  - `struct version_t { int major; int minor; int patch; auto operator<=>(const version_t &) const = default; };`
  - `std::optional<version_t> parse_version(std::string_view text);` — só `x.y.z`, cada parte 0–999.
  - `std::string to_string(const version_t &);`
  - `struct artifact_t { std::string file; std::string sha256; std::uint64_t size; };`
  - `struct manifest_t { version_t version; std::string date; std::string notes; artifact_t host; version_t min_app; artifact_t app; int version_code; version_t min_host; };`
  - `std::optional<manifest_t> parse_manifest(std::string_view json);` — regras de validação do topo (nlohmann::json).
  - `bool verify_signature(std::string_view data, std::string_view signature, std::string_view public_key_raw);` — OpenSSL `EVP_PKEY_new_raw_public_key(EVP_PKEY_ED25519, …)` + `EVP_DigestVerify`; `signature` com 64 bytes, chave com 32.
  - `std::optional<manifest_t> load_verified(std::string_view json, std::string_view signature, std::string_view public_key_raw);` — assinatura primeiro, depois parse.
  - `std::string sha256_file(const std::filesystem::path &file);` — hex minúsculo, vazio em erro.
  - `update_key.h`: `inline constexpr std::string_view kPublicKeyBase64 = "<pública da Task 1>";`
  - `update_policy.h`: `enum class action_e { wait, check, download, install };` `struct policy_input_t { std::chrono::seconds since_start; std::optional<std::chrono::seconds> since_last_check; bool last_check_failed; std::optional<version_t> available; bool installer_ready; version_t installed; int sessions; int running_apps; bool user_asked_check; bool user_asked_install; };` `action_e next_action(const policy_input_t &);`
- Regras de `next_action` (as constantes ficam no `.cpp`): primeira conferência 2 min depois de subir; depois a cada 24 h; depois de falha, de novo em 1 h; `user_asked_check` confere já; `available` > `installed` e sem instalador pronto → `download`; instalador pronto → `install` só com `sessions == 0 && running_apps == 0` (vale também para `user_asked_install`); senão `wait`.

- [ ] **Step 1: Testes que falham** em `test_update.cpp`:
  - `UpdateVersion.ParsesAndCompares`: `0.4.1 > 0.4.0`, `0.10.0 > 0.9.9`; recusa `v0.4.0`, `0.4`, `1.2.3-beta`, `1000.0.0`.
  - `UpdateManifest.AcceptsSignedFixture`: `load_verified(manifest.json, manifest.json.sig, chave de teste)` → versão 0.4.1, `version_code` 4001, `host.file == "GabsRemote-Setup-0.4.1.exe"`.
  - `UpdateManifest.RejectsTamperedManifest` (`manifest-adulterado.json` com a assinatura original) e `UpdateManifest.RejectsOtherKey` (`manifest-outra-chave.json.sig`) → vazio.
  - `UpdateManifest.RejectsBadFields`: `file` com `..`, `sha256` com 63 dígitos, `schema` 2, `versionCode` que não bate → vazio.
  - `UpdatePolicy.FirstCheckAfterTwoMinutes`, `UpdatePolicy.ChecksEvery24Hours`, `UpdatePolicy.RetriesAfterOneHourOnFailure`, `UpdatePolicy.IgnoresOlderOrEqualVersion` (`available` 0.4.0 com `installed` 0.4.0 → `wait`), `UpdatePolicy.WaitsWhileSessionOrAppRunning` (`sessions 1` → `wait`; `sessions 0, running_apps 1` → `wait`; ambos 0 → `install`), `UpdatePolicy.UserCheckIsImmediate`.
  Rodar `build-host.ps1 -Testes` e `test_sunshine.exe --gtest_filter=Update*`: não compila/FAIL.
- [ ] **Step 2: Implementar** `update_manifest.*`, `update_policy.*` e `update_key.h`. Rodar: PASS, e a suíte inteira sem falha nova.
- [ ] **Step 3: Commit** — no submódulo `feat(gabs): manifesto assinado e política do updater`; no principal o ponteiro.

### Task 5: Host — serviço de atualização, bandeja e painel

**Files:**
- Create: `host/src/gabs/update_service.h`, `host/src/gabs/update_service.cpp`, `host/src/platform/windows/gabs/update_launch_win.cpp`
- Modify: `host/src/main.cpp` (sobe o serviço junto da presença), `host/src/system_tray.{h,cpp}` (`update_tray_update_ready`), `host/src/confighttp.cpp` (rotas perto de `^/api/restart$`, linha ~2508), `host/src_assets/common/assets/web/Home.vue:204-206` e `Apps.vue:788` (tirar as consultas ao GitHub do LizardByte), `.../public/assets/locale/en.json` e `pt_BR.json` (chaves `gabs_update.*`), `cmake/compile_definitions/common.cmake` e `windows.cmake`
- Test: `host/tests/unit/gabs/test_update.cpp` (suíte `UpdateFiles`)

**Interfaces:**
- Consumes: Task 4 inteira; `rtsp_stream::session_count()`, `proc::proc.running()`.
- Produces (em `namespace gabs::update`):
  - `enum class state_e { idle, checking, up_to_date, downloading, ready, installing, error };`
  - `struct status_t { std::string installed; std::string latest; std::string notes; state_e state; std::string error; };` — `error` em pt-BR para o painel.
  - `status_t status();` `void request_check();` `bool request_install();` (falso com sessão ou app rodando, ou sem instalador pronto).
  - `std::unique_ptr<platf::deinit_t> start();` — uma thread que consulta `next_action` a cada 60 s.
  - Arquivos (testáveis sem rede): `std::filesystem::path updates_dir();` (= `<pasta config>/updates`); `bool finish_download(const std::filesystem::path &part, const artifact_t &expected);` — confere tamanho e SHA-256 do `.part` e só então renomeia para o nome final, senão apaga; `void clean_updates_dir(const version_t &installed);` — apaga `.part` e instaladores de versão ≤ instalada.
  - Windows: `bool launch_installer(const std::filesystem::path &exe);` — `CreateProcessW` com `"<exe>" /S /ATUALIZACAO`, `CREATE_BREAKAWAY_FROM_JOB | DETACHED_PROCESS | CREATE_NO_WINDOW`.
  - Bandeja: `void system_tray::update_tray_update_ready(const std::string &version);` — título "Gabs Remote <versão> pronta", texto "Instala sozinha quando não houver sessão. Notas no painel."
  - Painel (autenticado, POST com CSRF como o `restart`): `GET /api/gabs/update` → `{"installed","latest","notes","state","error"}` (`state` em minúsculas como no enum); `POST /api/gabs/update/check` → `{"status":true}`; `POST /api/gabs/update/install` → `{"status":true}` ou `{"status":false,"error":"Há uma sessão ativa. A atualização instala quando ela terminar."}`.
- Fluxo de download: manifesto e `.sig` por curl (`CURLOPT_FOLLOWLOCATION`, `CURLOPT_PROTOCOLS_STR`/`CURLOPT_REDIR_PROTOCOLS_STR` = `"https"`, tempo limite 30 s para o manifesto, 30 min para o instalador, aborta se passar de `size` bytes), `load_verified` com `kPublicKeyBase64`, instalador gravado em `<nome>.part`, `finish_download`. Antes de `launch_installer`, `sha256_file` de novo.

- [ ] **Step 1: Testes que falham** (suíte `UpdateFiles`, em pasta temporária): `UpdateFiles.PartialFileNeverReady` (`.part` com hash errado → `false`, `.part` apagado, nenhum arquivo final); `UpdateFiles.ReadyAfterHashMatches` (hash e tamanho certos → arquivo final existe, `.part` não); `UpdateFiles.CleansOldInstallers` (instaladores 0.4.0 e 0.4.1 com instalada 0.4.1 → sobra nenhum; 0.4.2 fica). Rodar: FAIL.
- [ ] **Step 2: Implementar** `update_service.*` e `update_launch_win.cpp`; subir em `main.cpp` junto da presença. Rodar os testes: PASS.
- [ ] **Step 3: Painel.** Rotas no `confighttp.cpp`; em `Home.vue`, no lugar do bloco de versão do Sunshine: versão instalada, estado, versão disponível com as notas (texto simples, quebras de linha preservadas, sem `v-html`) e os botões "Procurar atualizações" e "Instalar agora" (desabilitado fora de `ready`). Tirar o `fetch` do GitHub do LizardByte em `Home.vue` e `Apps.vue` (o de `Troubleshooting.vue` é do driver de entrada e fica). Textos em `pt_BR.json` e `en.json`.
- [ ] **Step 4: Verificar em console**, ainda sem Release publicada: "Procurar atualizações" no painel → estado `error` com "Nenhuma versão publicada ainda" (404 do GitHub) no painel e no log; uma sessão aberta ao mesmo tempo segue sem engasgo. O teste de ponta a ponta (download, bandeja, instalação) fica para as Tasks 10 e 11.
- [ ] **Step 5: Commit** — no submódulo `feat(gabs): updater do host, bandeja e painel`; no principal o ponteiro.

### Task 6: Instalador NSIS e configuração do host

**Files:**
- Create: `installer/gabs-remote.nsi`, `installer/configurar-host.ps1`, `installer/configurar-host.Tests.ps1`, `tools/build/build-instalador.ps1`
- Modify: `tools/setup/instalar-host.ps1` (passa a chamar `installer\configurar-host.ps1` depois do `cmake --install`), `tools/setup/instalar-host.Tests.ps1` (os testes de regras e recuperação vão para `configurar-host.Tests.ps1`)

**Interfaces:**
- Produces:
  - `configurar-host.ps1 -Pasta <dir> [-Atualizacao] [-Desinstalar]` com as funções `Get-RegrasFirewall`, `Get-ArgumentosRecuperacao` (movidas do `instalar-host.ps1`, mesmos valores) e `Set-AclPastaUpdates -Pasta <config\updates>` (dono Administradores; SYSTEM e Administradores controle total; sem herança). Faz: cria `config\updates` com esse ACL; serviço (`scripts\install-service.bat`, `autostart-service.bat`, `sc.exe failure`); regras de firewall (remove e recria); SudoVDA (`drivers\sudovda\install.bat`) só se `pnputil /enum-devices /hwid root\sudomaker\sudovda` não achar o dispositivo e nunca com `-Atualizacao`; inicia o serviço. `-Desinstalar` desfaz e mantém `config`.
  - `build-instalador.ps1` → `installer\out\GabsRemote-Setup-<versão>.exe`: `cmake --install host/build --prefix installer/out/stage`, copia `drivers\sudovda` e `configurar-host.ps1` para o stage, `makensis -DVERSION=<versão> -DSTAGE=<stage> installer\gabs-remote.nsi` (NSIS do MSYS2 UCRT64).
  - `gabs-remote.nsi`: `RequestExecutionLevel admin`; pasta fixa `$PROGRAMFILES64\Gabs Remote`; para o serviço e o `sunshine.exe` da pasta; copia o stage **exceto** `config\`; roda `powershell -NoProfile -ExecutionPolicy Bypass -File configurar-host.ps1 -Pasta "$INSTDIR"` (+ `-Atualizacao` quando a linha de comando tiver `/ATUALIZACAO`); grava o desinstalador e a entrada em "Aplicativos" (nome "Gabs Remote", versão, editor "Gab Tavares"); ícone de `tools/marca`. Com `/S`, nenhuma janela. Saída com código ≠ 0 se o `configurar-host.ps1` falhar.

- [ ] **Step 1: Testes que falham** em `configurar-host.Tests.ps1`: todas as regras de `Get-RegrasFirewall` têm `EnderecoRemoto` só `LocalSubnet` ou `100.64.0.0/10` e nome começando com `Gabs Remote `; `Get-ArgumentosRecuperacao` igual ao de hoje; com `Mock` de `pnputil`, `-Atualizacao` nunca chama o `install.bat` do SudoVDA e a instalação normal só chama quando o dispositivo não existe; nenhuma operação de cópia ou remoção recebe caminho dentro de `config` (Mock de `Remove-Item`/`Copy-Item`). Rodar `Invoke-Pester C:\gr\installer\configurar-host.Tests.ps1`: FAIL.
- [ ] **Step 2: Implementar** `configurar-host.ps1` e ajustar `instalar-host.ps1`. Rodar os Pester do instalador e do `instalar-host`: PASS.
- [ ] **Step 3: `gabs-remote.nsi` e `build-instalador.ps1`.** Gerar o instalador local com a versão do `versao.json`.
- [ ] **Step 4: Verificar no PC** (o Gab roda como administrador): com o serviço atual parado, rodar o instalador interativo por cima da instalação da fase 3 → pareamento continua (o tablet conecta sem PIN), painel com o mesmo login, `Get-NetFirewallRule -DisplayName 'Gabs Remote*'` igual ao de antes, `icacls "C:\Program Files\Gabs Remote\config\updates"` só SYSTEM e Administradores. Depois `GabsRemote-Setup-<v>.exe /S /ATUALIZACAO` → serviço volta sozinho, sem janela. Anotar no rascunho de `docs/testes/fase-4-checklist.md`.
- [ ] **Step 5: Commit** — `feat(installer): instalador NSIS e configurar-host.ps1`.

### Task 7: App — updater

**Files:**
- Create em `android/app/src/main/java/com/limelight/gabs/update/`: `Version.java`, `UpdateManifest.java`, `ManifestVerifier.java`, `UpdateKey.java`, `UpdateChecker.java`, `ApkInstaller.java`, `UpdateDialog.java`
- Create: `android/app/src/test/java/com/limelight/gabs/update/VersionTest.java`, `UpdateManifestTest.java`, `ManifestVerifierTest.java`, `UpdateCheckerTest.java`; `android/app/src/test/resources/update/` (cópia de `tools/release/testdata/`, sem o `.pem`)
- Modify: `AndroidManifest.xml` (`REQUEST_INSTALL_PACKAGES` e o receiver do resultado da instalação), `PcView.java` (`onCreate`: confere uma vez por processo), `res/xml/preferences.xml` + `StreamSettings` (item "Procurar atualizações" com a versão no resumo), `res/values/strings.xml` e `values-pt-rBR/strings.xml`, `proguard-rules.pro` (manter `org.bouncycastle.math.ec.rfc8032` e `org.bouncycastle.crypto.signers.Ed25519Signer` se o R8 os remover)

**Interfaces:**
- Consumes: `BuildConfig.VERSION_NAME`, `BuildConfig.VERSION_CODE` (Task 3); fixture da Task 2.
- Produces (pacote `com.limelight.gabs.update`):
  - `final class Version implements Comparable<Version>`: `static Version parse(String)` (null se inválida, mesmas regras do host), `toString()`.
  - `final class UpdateManifest`: campos `version`, `date`, `notes`, `appFile`, `appSha256`, `appSize`, `versionCode`, `minHost`, `hostVersion`(= `version`), `minApp`; `static UpdateManifest parse(String json)` (null se inválido; org.json).
  - `final class ManifestVerifier`: `static boolean verify(byte[] data, byte[] signature, byte[] publicKeyRaw)` com `org.bouncycastle.crypto.signers.Ed25519Signer`.
  - `final class UpdateKey { static final String PUBLIC_KEY_BASE64 = "<pública da Task 1>"; }`
  - `final class UpdateChecker`: `interface Fetcher { byte[] get(String url) throws IOException; }`; `UpdateChecker(Fetcher, byte[] publicKeyRaw, Version installed)`; `Result check()` com `Result.kind` ∈ `UP_TO_DATE`, `AVAILABLE`, `INVALID`, `FAILED` e `Result.manifest`. URLs das Global Constraints. O `Fetcher` real usa OkHttp com `followSslRedirects(false)` e tempo limite de 15 s.
  - `final class ApkInstaller`: `static void downloadAndInstall(Activity, UpdateManifest)` — baixa para `getCacheDir()/updates/<appFile>.part` (OkHttp, aborta acima de `appSize`), confere SHA-256, renomeia, confere com `PackageManager.getPackageArchiveInfo` que o pacote é `getPackageName()` e o `versionCode` é o do manifesto, e instala por `PackageInstaller` (`SessionParams.MODE_FULL_INSTALL`; na API 31+ `setRequireUserAction(USER_ACTION_NOT_REQUIRED)`); o resultado vai para o receiver, que abre a confirmação do sistema quando vier `STATUS_PENDING_USER_ACTION` e mostra `Toast` de erro em pt-BR.
  - `final class UpdateDialog`: `static void show(Activity, UpdateManifest)` — `AlertDialog` "Gabs Remote <versão> disponível", notas, botões "Atualizar" e "Depois"; sem permissão de instalar desta fonte, abre `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` para o próprio pacote.

- [ ] **Step 1: Testes que falham:**
  - `VersionTest`: ordem `0.4.1 > 0.4.0`, `0.10.0 > 0.9.9`; `parse("v0.4.0")`, `parse("0.4")`, `parse("1.2.3-beta")` → null.
  - `UpdateManifestTest`: a fixture vira `version 0.4.1`, `versionCode 4001`, `appFile "GabsRemote-0.4.1.apk"`; `file` com `..`, `sha256` maiúsculo, `schema 2` e `versionCode` errado → null.
  - `ManifestVerifierTest.acceptsFixture`, `ManifestVerifierTest.rejectsTampered` (adulterado), `ManifestVerifierTest.rejectsOtherKey`.
  - `UpdateCheckerTest` com `Fetcher` falso: fixture com instalada 0.4.0 → `AVAILABLE`; `ignoresOlderOrEqual` (instalada 0.4.1 → `UP_TO_DATE`); assinatura trocada → `INVALID`; `IOException` → `FAILED`.
  Rodar `build-android.ps1 -Testes`: FAIL.
- [ ] **Step 2: Implementar** as classes e os encaixes (manifesto, `PcView`, preferências, strings, ProGuard). Rodar os testes: PASS.
- [ ] **Step 3: Verificar o build de release:** `build-android.ps1 -Release`, instalar no tablet; abrir o app sem Release publicada → nenhum diálogo e nenhum travamento; "Procurar atualizações" mostra `Toast` "Nenhuma versão publicada ainda" (404). O fluxo completo fica para as Tasks 10 e 11.
- [ ] **Step 4: Commit** — no submódulo `feat(gabs): updater do app`; no principal o ponteiro.

### Task 8: App — compatibilidade com o host antes de conectar

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/update/Compat.java`, `android/app/src/test/java/com/limelight/gabs/update/CompatTest.java`
- Modify: `android/app/src/main/java/com/limelight/utils/ServerHelper.java:87` (`doStart`), strings

**Interfaces:**
- Consumes: `ComputerDetails.gabsVersion`, `ComputerDetails.gabsMinApp` (Task 3), `BuildConfig.GABS_MIN_HOST`, `Version` e `UpdateChecker`/`UpdateDialog` (Task 7).
- Produces: `enum Compat.Result { OK, APP_TOO_OLD, HOST_TOO_OLD }`; `static Compat.Result check(String appVersion, String appMinHost, String hostVersion, String hostMinApp)` — `hostVersion` nulo ou inválido → `OK` (host anterior à fase 4); app < `hostMinApp` → `APP_TOO_OLD`; host < `appMinHost` → `HOST_TOO_OLD`.

- [ ] **Step 1: Testes que falham** em `CompatTest`: host sem versão → `OK`; `("0.4.0","0.4.0","0.5.0","0.5.0")` → `APP_TOO_OLD`; `("0.5.0","0.5.0","0.4.0","0.4.0")` → `HOST_TOO_OLD`; iguais → `OK`; versão lixo do host → `OK`. Rodar: FAIL.
- [ ] **Step 2: Implementar** `Compat` e o encaixe em `ServerHelper.doStart`: `OK` segue; `APP_TOO_OLD` → `AlertDialog` "Este app é mais antigo do que o PC aceita (PC <versão>)" com "Atualizar o app" (roda o `UpdateChecker` e abre o `UpdateDialog`) e "Conectar mesmo assim"; `HOST_TOO_OLD` → "O PC está na versão <x> e este app precisa da <y>. O PC se atualiza sozinho quando não houver sessão, ou pelo painel: Procurar atualizações." com "Conectar mesmo assim" e "Cancelar". Rodar os testes: PASS.
- [ ] **Step 3: Commit** — no submódulo `feat(gabs): aviso de versão incompatível antes de conectar`; no principal o ponteiro.

### Task 9: CI no GitHub Actions

**Files:**
- Create: `.github/workflows/testes.yml`, `.github/workflows/release.yml`, `docs/release.md` (como fazer uma Release, passo a passo, em pt-BR)

**Interfaces:**
- Consumes: `build-instalador.ps1` (Task 6), `Release.psm1` (Task 2), `versao.json`, `docs/notas/<versão>.md`.
- Produces:
  - `testes.yml` (push em `main`, pull request, manual), `permissions: contents: read`, checkout com `submodules: recursive`, quatro jobs: **app** (`ubuntu-latest`, JDK 17, `./gradlew testNonRootDebugUnitTest` em `android/`); **scripts** (`windows-latest`, Pester 5: `tools/**/*.Tests.ps1` e `installer/*.Tests.ps1`; testes que exigem `C:\gr` ou administrador ficam com a tag `Local` e o CI roda `-ExcludeTagFilter Local`); **presenca** (`ubuntu-latest`, `php web/presenca/tests/…` como na fase 3); **host** (`windows-2022`, MSYS2 UCRT64 com a lista de pacotes e as versões fixadas das actions copiadas de `host/.github/workflows/ci-windows.yml`, mais `mingw-w64-ucrt-x86_64-nsis`; Node LTS; `cmake -DBUILD_TESTS=ON -DBUILD_DOCS=OFF`, `ninja`, e `test_sunshine.exe --gtest_filter=` com as suítes do Gabs Remote e as do upstream que o `ci-windows.yml` roda).
  - `release.yml` (tag `v*` ou manual com a tag), `permissions: contents: write`: confere que a tag é `v` + `versao.json`; build do host como acima (sem testes, `BUILD_VERSION`/`BRANCH`, `-DGABS_MIN_APP`), `build-instalador.ps1 -Msys2 ${{ steps.msys2.outputs.msys2-location }}` (o script ganha o parâmetro `-Msys2`, padrão `C:\msys64`; o caminho do runner não tem espaço); build do app `assembleNonRootRelease -PgabsVersion -PgabsMinHost` **sem keystore** → `GabsRemote-<v>-unsigned.apk`; `gh release create v<v> --draft --title "Gabs Remote <v>" --notes-file docs/notas/<v>.md` com os dois arquivos. Nunca publica.

- [ ] **Step 1: Escrever os dois workflows e `docs/release.md`** (passos: editar `versao.json` e `docs/notas/<v>.md` → commit → tag `v<v>` e push → esperar o rascunho → `preparar-release.ps1 -Versao <v>` (o Gab digita as senhas) e depois `-Enviar` → publicar com `gh release edit v<v> --draft=false`).
- [ ] **Step 2: Conferir localmente o que der:** `actionlint` (se instalado; senão revisão à mão das chaves e dos `uses:` fixados por SHA como no upstream); `Invoke-Pester -ExcludeTagFilter Local` em todos os testes de scripts passa.
- [ ] **Step 3: Commit** — `ci: testes e rascunho de Release no GitHub Actions`.
- [ ] **Step 4: Rodar o CI:** push do principal e dos submódulos; o `testes.yml` fica verde. Se um job falhar por ambiente do runner, corrigir e repetir; anotar o tempo de cada job no rascunho do checklist.

### Task 10: Primeira Release (0.4.0) e instalação manual

**Files:**
- Modify: `docs/notas/0.4.0.md`, rascunho de `docs/testes/fase-4-checklist.md`

- [ ] **Step 1:** tag `v0.4.0` no principal e push; o `release.yml` cria o rascunho com `GabsRemote-Setup-0.4.0.exe` e `GabsRemote-0.4.0-unsigned.apk`.
- [ ] **Step 2: O Gab roda** `powershell -File C:\gr\tools\release\preparar-release.ps1 -Versao 0.4.0` (digita as senhas), confere o resumo e roda de novo com `-Enviar`. Conferir no rascunho: `.exe`, `.apk` assinado, `manifest.json`, `manifest.json.sig`, nenhum `-unsigned`.
- [ ] **Step 3: Publicar** o rascunho (`gh release edit v0.4.0 --draft=false`).
- [ ] **Step 4: Instalar à mão** a 0.4.0: no PC, baixar `GabsRemote-Setup-0.4.0.exe` da Release e instalar (SmartScreen: "Mais informações › Executar assim mesmo"); no tablet, baixar `GabsRemote-0.4.0.apk` pelo navegador e instalar por cima do build atual (mesma assinatura → atualiza, sem perder os PCs pareados). Conferir: painel "0.4.0 · Em dia"; app abre sem oferecer atualização; sessão funciona como antes.
- [ ] **Step 5: Commit** — `docs: primeira Release 0.4.0`.

### Task 11: Testes em lote (fase 3 + fase 4) e fechamento

**Files:**
- Create: `docs/testes/fase-4-checklist.md`, `docs/notas/0.4.1.md`
- Modify: `versao.json` (0.4.1), `docs/testes/fase-3-checklist.md`, `docs/sessoes.md`, `CLAUDE.md` (módulos novos: `host/src/gabs/update_*`, `android/.../gabs/update/`, `installer/`, `tools/release/`, `versao.json`, `docs/release.md`), `graphify-out/`

Uma sessão de testes junta o que a fase 3 deixou para o escritório e o critério 7 com duas versões reais.

- [ ] **Step 1: Segunda versão 0.4.1** (pode ser só as notas e um ajuste pequeno que já esteja pronto, ex.: o padrão de latência da Task 9 da fase 3): `versao.json` 0.4.1, `docs/notas/0.4.1.md`, commit, e o caminho da Task 10 Steps 1–3 (tag, `preparar-release`, publicar).
- [ ] **Step 2: Critério 7 no app:** abrir o app → diálogo "Gabs Remote 0.4.1 disponível" com as notas → Atualizar → (na primeira vez, permitir "instalar apps desta fonte") → o app reinstala por cima, os PCs pareados continuam, Configurações mostra 0.4.1. Anotar quantos toques foram.
- [ ] **Step 3: Critério 7 no host:** com uma sessão aberta, "Procurar atualizações" no painel → estado `ready` e notificação na bandeja, mas **não** instala; "Instalar agora" responde que há sessão. Desconectar no app (Desconectar, sem deixar o PC "pronto") → em até 5 min o serviço reinicia sozinho na 0.4.1, painel "0.4.1 · Em dia", log sem erro, tablet conecta sem novo pareamento. Conferir também a espera de 24 h pelo log (próxima conferência agendada).
- [ ] **Step 4: Roteiro do escritório da fase 3** (`docs/testes/fase-3-checklist.md`, "Pendente"): (1) caminho e latência no Wi-Fi do escritório a 120 fps, Toast, `tailscale status` (direto ou DERP), medidor com 40 amostras de clique e carimbo, comparação à mão com o Acesso Remoto do Google; (2) 15 min de uso real com VS Code e navegador, quedas e reconexões; (3) WoL de fora: PC desligado pelo Iniciar antes de sair, "Enviar WoL" do escritório, tempo até a lista de apps.
- [ ] **Step 5: Task 9 da fase 3 em casa** (latência ≤ 30 ms, um ajuste por vez, roteiro no plano da fase 3). Ajuste adotado no app vira versão 0.4.2 pelo mesmo caminho, se o Gab quiser.
- [ ] **Step 6: Pendências fora do código:** prova do backup da keystore **e** da chave Ed25519 (baixar o `.7z` do Drive, extrair numa pasta temporária, `Get-FileHash` dos dois arquivos contra `docs/segredos.md`, apagar a pasta, anotar a data).
- [ ] **Step 7: Escrever `docs/testes/fase-4-checklist.md`** com ✓/✗ e evidência para: critério 7 (app e host, duas versões reais), manifesto assinado (Review Focus 1–5), CI verde (tempos), instalador sobre a instalação manual, ACL de `config\updates`, firewall igual. Fechar `docs/testes/fase-3-checklist.md` com os números do escritório e da Task 9.
- [ ] **Step 8: Atualizar** `CLAUDE.md`, `docs/sessoes.md` (fases 3 e 4 feitas, estado ao fechar, prompt da fase 5) e o grafo (`/graphify . --update`).
- [ ] **Step 9: Commit** — `docs: testes em lote e fechamento das fases 3 e 4`. Push.

---

## Fora deste plano
- Certificado de assinatura de código do Windows (SignPath/Azure): sem ele, o SmartScreen avisa só na primeira instalação manual; as atualizações silenciosas rodam como SYSTEM e não passam pelo SmartScreen.
- Atualizar o host a partir do app (pedido remoto de "atualize agora"): o host já se atualiza sozinho em até 24 h; fica para a fase 7 se fizer falta.
- Publicar a presença na hospedagem (exclusão no `rsync --delete` do deploy do site): continua fora, como decidido em 09/11/2026.
- Canal beta / pré-releases e volta de versão: não; só a última Release publicada vale.
- Habilitar os workflows do upstream nos forks.

## Próxima sessão

Para **executar este plano**, comece uma sessão nova e use:

> Gabs Remote — executar o plano `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md`. Leia o `CLAUDE.md`, o plano, as decisões em `docs/decisoes/` e `docs/segredos.md`. Execução nativa (executing-plans), fazendo commit, push, tag e Release sem pedir (só peça meu ok se algo afetar outro projeto meu); eu digito as senhas e rodo o instalador como administrador. A Task 1 precisa de mim no terminal para criar a chave. Pare depois da Task 10 (primeira Release instalada): a Task 11 é a sessão de testes em lote. Ao parar, atualize `docs/sessoes.md` e me dê o prompt da próxima sessão.

Se a execução parar no meio:

> Gabs Remote — continuar a execução de `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md`. Leia o `CLAUDE.md`, confira no `git log` (principal e submódulos), nos checkboxes e no ledger `.superpowers/sdd/` o que já foi feito e siga da próxima tarefa.

Para a **sessão de testes em lote** (Task 11, fase 3 + fase 4), depois da 0.4.0 instalada:

> Gabs Remote — sessão de testes em lote: Task 11 do plano `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md` (Release 0.4.1 e critério 7 no app e no host) junto do roteiro pendente em `docs/testes/fase-3-checklist.md` (escritório, WoL de fora e a Task 9 da fase 3). Leia o `CLAUDE.md`, os dois checklists e `docs/release.md`. Eu trago os números do escritório. Commit, push, tag e Release sem pedir. No fim, escreva `docs/testes/fase-4-checklist.md`, feche o da fase 3, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt do plano da fase 5.
