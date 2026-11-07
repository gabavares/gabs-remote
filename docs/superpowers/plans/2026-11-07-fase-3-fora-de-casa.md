# Fase 3 — Fora de casa completo: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O Gab liga o PC de fora de casa, o app escolhe sozinho o melhor caminho (rede de casa → IPv6 direto → IPv4 com porta aberta → Tailscale) e mostra qual usa, a sessão volta sozinha quando a rede do tablet muda, e a latência de clique até a imagem fica medida em casa (meta ≤ 30 ms) e fora.

**Architecture:** O app ganha um módulo `gabs/net/` que classifica cada endereço do PC (casa, IPv6, IPv4 público, Tailscale), testa todos em paralelo e escolhe pelo menor tempo de resposta com desempate pela ordem da spec; ele entra no lugar da espera em ordem fixa do `parallelPollPc` do upstream. Os endereços públicos do PC chegam por uma página de presença em PHP na hospedagem do Gab, que o host atualiza (só se a Task 1 mostrar que há caminho direto possível). A reconexão fica no app (`gabs/session/`), reaproveitando a decisão 0004: o host já mantém o PC pronto quando o tablet some; o app só precisa achar o PC de novo e reabrir a sessão sem mandar `/cancel`. O WoL de fora usa o mesmo mecanismo da Alexa; o host passa a informar o MAC da placa física mesmo quando o pedido chega pelo Tailscale.

**Tech Stack:** C++20 + GoogleTest (host, MSYS2 UCRT64), Java 17 + JUnit 4 (app), PHP 8 da Hostinger (presença, testes em script PHP puro rodado por SSH), PowerShell 5.1 + Pester 5 (scripts), Tailscale oficial.

**Spec:** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§1.1 critérios 1 e 6, §5 Rede e conexão, §7, §10 linha da fase 3, §11). Decisões: `docs/decisoes/0004-pc-pronto-em-segundo-plano.md`. Linha de base: `docs/testes/fase-2-checklist.md`. Acesso atual de fora: `docs/tailscale.md`. Hospedagem: `docs/resposta servidor.md`.

## Decisões do Gab para esta fase (07/11/2026)
- **Sem 2º fator** e **sem bloqueio do PC ao desconectar**: o Gab mora sozinho e não precisa dessa privacidade. Sai da spec (§5.4) pela decisão 0005 (Task 1).
- **WoL de fora:** hoje a Alexa liga o PC por uma **skill/app de WoL**. A Task 1 descobre qual e como o app chama o mesmo.
- A reconexão automática **não muda** a decisão 0004: o PC continua pronto sem tempo limite; o app só reabre a sessão.

## Global Constraints
- Docs, notas, UI e mensagens ao Gab em **pt-BR**; código e identificadores em inglês, seguindo o upstream. Toda mudança em arquivo do upstream leva o comentário `// Gabs Remote:`.
- **Todo build roda por `C:\gr`**. Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Testes] [-Jobs 8]`, nunca mais de 8 jobs. App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Release] [-Instalar]`.
- Testes do host: `C:\gr\host\build\tests\test_sunshine.exe --gtest_filter=<Suite>.*`. Testes do app: `build-android.ps1 -Testes`.
- Com o serviço `GabsRemote` rodando, pare-o (`Stop-Service GabsRemote`) antes de testar o `sunshine.exe` do build em console. Para pôr o host novo no serviço: `instalar-host.ps1` (o Gab roda como administrador).
- Scripts `.ps1` em UTF-8 **com BOM**.
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>` e `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Submódulo primeiro, depois o principal com o ponteiro.
- **Push, Release, criar repositório: só com o ok do Gab no chat.** Mudar o roteador, regra de firewall, serviço, e qualquer coisa na hospedagem: o Gab faz ou dá o ok no momento.
- **Hospedagem:** nunca mexer no site `gabtavares.com`, no `/privado`, no `/mcp`, no Vagabs, no `vigia.sh`, na fila/executor do Claude, nos e-mails nem no `/sample`. A presença vive num subdomínio novo e numa pasta própria `~/gabs-remote/`; nada de processo persistente nem cron.
- Segredos (token da presença, URL secreta da skill de WoL) **nunca** entram em repositório nem na conversa. O Gab digita no app e cria os arquivos no PC e no servidor.
- Interface nova só com componentes padrão do Android (`AlertDialog`, `Toast`, `PopupMenu`, telas de preferência do upstream); layout próprio é da fase 7.
- O painel web (47990) continua só local: nenhuma regra nova o abre.

## Review Focus
1. **Tablet numa rede de outra casa/escritório com a mesma faixa `192.168.x`.** O endereço de casa do PC pode cair noutro aparelho. Esperado: a resposta com outro uuid é descartada e o app usa o caminho remoto. Teste `ParallelPathPollerTest.lanFailureFallsBackToRemote` (Task 6).
2. **Troca de rede no meio da sessão (Wi-Fi ↔ 4G).** Esperado: o app reconecta sozinho e o PC não recebe `/cancel` (a tela virtual é reaproveitada). Testes `SessionExitTest.reconnectDoesNotQuitHostApp` e `ReconnectPolicyTest` (Task 8), item manual na Task 10.
3. **Presença fora do ar, lenta ou com token errado.** Esperado: o app segue com os endereços que já conhece (casa, manual/Tailscale) sem ficar mais lento para achar o PC. Testes `PresenceClientTest.parseRejectsMalformed` e `ParallelPathPollerTest.slowCandidateDoesNotBlockChoice` (Task 6).
4. **PC desligado que não liga** (skill fora do ar, PC sem energia). Esperado: "Ligando…" desiste em 3 min com mensagem clara, sem ficar preso. Teste `WakeFlowTest.timesOutAfterThreeMinutes` (Task 7).
5. **Pedido de `/serverinfo` chegando pelo Tailscale** (placa virtual sem MAC). Esperado: o host responde com o MAC da placa física de rede, sem encher o log. Teste `WolMac.FallsBackToPhysicalAdapter` (Task 2).

---

### Task 1: Diagnóstico da rede de fora, WoL da Alexa e decisão 0005

**Files:**
- Create: `docs/rede-fora.md`, `docs/decisoes/0005-fora-de-casa.md`
- Modify: `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§5.2, §5.3, §5.4, §10 linha 3, §11)

**Interfaces:**
- Produces: em `docs/rede-fora.md` e na decisão 0005, o resultado de cada caminho — **IPv6 direto** (sim/não), **IPv4 com porta aberta** (sim/não: CGNAT?), **Tailscale** (sim) — e o **mecanismo do WoL de fora** num destes tipos: `URL` (uma URL HTTP que o app chama), `APP` (abrir um app no tablet, ex.: Alexa `com.amazon.dee.app`) ou `NENHUM`. As Tasks 4 e 5 só rodam se IPv6 ou IPv4 der "sim"; a Task 7 implementa o tipo escolhido.

- [ ] **Step 1: CGNAT.** O Gab abre a página do roteador Askey (normalmente `http://192.168.15.1`) e anota o IPv4 da WAN; no PC, `curl.exe -4 https://ifconfig.me`. Iguais = IPv4 público (port forward possível). WAN em `100.64.0.0/10` ou diferente = CGNAT (IPv4 descartado). Anotar também se o roteador tem UPnP ligado.
- [ ] **Step 2: IPv6 no PC.** `Get-NetIPAddress -AddressFamily IPv6 | Where-Object { $_.IPAddress -like '2*' -or $_.IPAddress -like '3*' }` mostra endereço global? Anotar o prefixo (sem o endereço inteiro no doc). No roteador: existe opção de firewall IPv6 de entrada (bloquear/permitir) ou de "pinhole"/UPnP IPv6?
- [ ] **Step 3: IPv6 de entrada de fato.** Com o host em console e a regra temporária `New-NetFirewallRule -DisplayName 'Gabs Remote teste IPv6' -Direction Inbound -Protocol TCP -LocalPort 47989 -Action Allow` (o Gab roda como administrador e a remove no fim do passo), o Gab, no 4G e no Wi-Fi do escritório, abre no navegador do tablet `http://[<ipv6-do-PC>]:47989/serverinfo`. Antes, o tablet tem IPv6 nessas redes? (abrir `https://test-ipv6.com`). Resposta XML = IPv6 direto "sim" naquela rede.
- [ ] **Step 4: WoL da Alexa.** O Gab abre o app Alexa e mostra (Mais › Skills e jogos › Suas skills, e Dispositivos) qual skill ou dispositivo "liga o PC", e se existe uma rotina. O Claude pesquisa a skill (site do autor) e classifica: se ela tem URL/webhook ou API própria que liga o PC → `URL`; se só funciona pela Alexa → `APP` (o app abre a Alexa e o Gab dispara a rotina); se depende de algo que só existe em casa e não tem como chamar de fora → `NENHUM` (fica o WoL de casa e o registro do pedido para a fase 7). Testar o tipo escolhido à mão, com o PC desligado, do 4G.
- [ ] **Step 5: Escrever `docs/rede-fora.md`** (o que cada caminho é, o resultado dos Steps 1–4 com data, como repetir o teste) e a **decisão 0005** (contexto; sem 2º fator e sem bloqueio ao desconectar, pedido do Gab em 07/11/2026; caminhos possíveis; mecanismo do WoL; se a presença na hospedagem será feita ou não). Na spec: §5.4 tira o 2º fator e o bloqueio citando a 0005; §5.2 e §5.3 registram o resultado; §10 linha 3 tira "2º fator, bloqueio ao desconectar"; §11 marca os riscos "CGNAT da Vivo" e "WoL de fora de casa" como resolvidos, com o resultado.
- [ ] **Step 6: Commit** — `docs: diagnóstico da rede de fora e decisão 0005`.

### Task 2: MAC certo para o WoL e conferência da placa

**Files:**
- Create: `host/src/gabs/network.h`, `host/src/gabs/network.cpp`, `host/src/platform/windows/gabs/adapters_win.cpp`, `host/tests/unit/gabs/test_network.cpp`
- Create: `tools/setup/conferir-wol.ps1`, `tools/setup/conferir-wol.Tests.ps1`
- Modify: `host/cmake/compile_definitions/common.cmake` (junto de `src/gabs/virtual_display.cpp`), `windows.cmake` (junto de `sudovda_driver.cpp`), `host/src/nvhttp.cpp:1279`

**Interfaces:**
- Produces (em `namespace gabs::network`):
  - `struct adapter_t { std::string mac; std::vector<std::string> addresses; bool physical; bool up; bool has_ipv4_gateway; };`
  - `std::string wol_mac_for(std::string_view local_address, const std::vector<adapter_t> &adapters);` — o MAC do adaptador que tem `local_address`, se ele tiver MAC; senão o do primeiro adaptador `physical && up && has_ipv4_gateway`; senão `"00:00:00:00:00:00"`.
  - `std::vector<adapter_t> enumerate_adapters();` (Windows, `GetAdaptersAddresses` com `GAA_FLAG_INCLUDE_GATEWAYS`; `physical` = `IfType` `IF_TYPE_ETHERNET_CSMACD` ou `IF_TYPE_IEEE80211`; `up` = `OperStatus == IfOperStatusUp`; `has_ipv4_gateway` = algum `FirstGatewayAddress` IPv4).
  - `std::string wol_mac_address(std::string_view local_address);` — `wol_mac_for(local_address, enumerate_adapters())`; loga `warning` só na primeira vez que cai no fallback para cada endereço.
  - Também usado pela Task 5: `struct ip_address_t { std::string address; bool deprecated; };` e `std::vector<ip_address_t> enumerate_ip_addresses();` em `adapters_win.cpp`.

- [ ] **Step 1: Testes que falham** em `test_network.cpp`:
  - `WolMac.UsesAdapterOfLocalAddress`: adaptador Ethernet `aa:..` com `192.168.15.10` → `wol_mac_for("192.168.15.10", …) == "aa:.."`.
  - `WolMac.FallsBackToPhysicalAdapter`: adaptador Tailscale sem MAC com `100.99.120.91` (não físico) + Ethernet físico, ligado, com gateway → devolve o MAC do Ethernet.
  - `WolMac.SkipsDownOrGatewaylessAdapters`: Wi-Fi físico desligado e vEthernet sem gateway antes do Ethernet → escolhe o Ethernet.
  - `WolMac.ZeroWhenNothingFits`: lista vazia → `"00:00:00:00:00:00"`.
  Rodar `build-host.ps1 -Testes` e `test_sunshine.exe --gtest_filter=WolMac.*`: não compila/FAIL.
- [ ] **Step 2: Implementar `network.{h,cpp}` e `adapters_win.cpp`.** Rodar: PASS.
- [ ] **Step 3: Encaixar** em `nvhttp.cpp:1279`: `tree.put("root.mac", gabs::network::wol_mac_address(net::addr_to_normalized_string(local_endpoint.address())));`. O `platf::get_mac_address` do upstream fica como está.
- [ ] **Step 4: `conferir-wol.ps1`** (spec §5.3, "o host confere se o WoL está ativo"): funções `Get-EstadoWol` (para cada `Get-NetAdapter -Physical` ligado: `Get-NetAdapterPowerManagement` → `WakeOnMagicPacket`) e `Get-InicioRapido` (`HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`, `HiberbootEnabled`), e uma saída em pt-BR com o que ajustar. Testes Pester com `Mock`: placa com `WakeOnMagicPacket = Enabled` → "WoL ativo na placa <nome>"; `Disabled` → orientação de ativar no Gerenciador de Dispositivos; `HiberbootEnabled = 1` → aviso de que o Início rápido pode impedir o WoL com o PC desligado. Rodar `Invoke-Pester C:\gr\tools\setup\conferir-wol.Tests.ps1`: PASS. Rodar o script real no PC e anotar em `docs/rede-fora.md`.
- [ ] **Step 5: Verificar** com o host em console: com o app na lista de PCs pelo Tailscale, o log não repete `Unable to find MAC address` e o app guarda o MAC do Ethernet (detalhes do PC no app).
- [ ] **Step 6: Commit** — no submódulo `fix(network): MAC da placa física para o WoL pelo Tailscale`; no principal `feat(tools): conferir WoL e Início rápido` com o ponteiro.

### Task 3: `WSASendMsg() failed: 10022` no início das sessões

**Files:**
- Modify (conforme a causa): `host/src/platform/windows/misc.cpp` (`send`, `send_batch`, `populate_source_pktinfo`, ~1530–1650) e/ou `host/src/stream.cpp` (envio de vídeo, ~1740–1900)
- Test: `host/tests/unit/gabs/test_send.cpp` se a causa estiver em código testável sem socket real

**Interfaces:**
- Produces: sessão a 90 e 120 fps, em casa e pelo Tailscale, sem nenhum `WSASendMsg() failed: 10022` no log.

Use superpowers:systematic-debugging. 10022 é `WSAEINVAL`; ele vem do `send()` sem lote, que é o caminho de reserva quando o `send_batch()` falha (o `send_batch` devolve `false` calado e o chamador tenta de novo pacote a pacote).

- [ ] **Step 1: Reproduzir e medir.** Host em console, `min_log_level = debug`, sessão Nativo a 120 fps em casa: contar as linhas 10022 e anotar em que momento aparecem (primeiros quadros? só vídeo? áudio também?).
- [ ] **Step 2: Instrumentar** temporariamente o `send()` para logar, na primeira falha de cada sessão: família do alvo, família do `source_address`, `cmbuflen`, tamanho do payload e se o socket é o de vídeo. Hipóteses a separar com essa saída: `source_address` ainda não preenchido (ou de outra família, IPv4 mapeado em IPv6) gerando `IN_PKTINFO` inválido; `UDP_SEND_MSG_SIZE` aceito no lote mas payload maior que o MTU no reserva; envio antes de o socket estar associado ao cliente.
- [ ] **Step 3: Corrigir a causa** com a menor mudança possível no código do upstream. Se a correção cair numa função pura (ex.: montar o controle do `WSAMSG`), extraí-la e escrever antes o teste GoogleTest que reproduz a entrada ruim. Tirar a instrumentação.
- [ ] **Step 4: Verificar:** sessões a 90 e 120 fps em casa e pelo Tailscale sem 10022; `build-host.ps1 -Testes` sem falha nova; clique até a imagem em casa a 120 fps (medidor, 40 amostras) não piora.
- [ ] **Step 5: Commit** — no submódulo `fix(stream): <causa> (WSASendMsg 10022)`; no principal o ponteiro e o rascunho `docs/testes/fase-3-checklist.md` (criado aqui, com causa e efeito; as Tasks 9 e 10 completam).

### Task 4: Página de presença na hospedagem (só se a Task 1 achou caminho direto)

**Files:**
- Create: `web/presenca/presenca.php`, `web/presenca/presenca_lib.php`, `web/presenca/testes.php`, `web/presenca/README.md` (como publicar)

**Interfaces:**
- Produces (contrato usado pelas Tasks 5 e 6):
  - `POST https://remote.gabtavares.com/presenca.php`, cabeçalho `Authorization: Bearer <token>`, corpo JSON `{"uuid": "<uniqueid do host>", "porta": 47989, "ipv6": ["2804:…"], "tailscale": ["100.99.120.91"], "versao": "<versão>"}`. O servidor acrescenta `ipv4` (o `REMOTE_ADDR`, se for IPv4) e `atualizado` (Unix, segundos), grava e responde `200` com o registro gravado.
  - `GET https://remote.gabtavares.com/presenca.php?uuid=<uuid>` com o mesmo cabeçalho → `200` com o registro, `404` se não houver.
  - Erros: token errado ou ausente `401`; corpo acima de 4096 bytes `413`; JSON inválido, uuid fora de `^[0-9A-Fa-f-]{36}$`, mais de 8 IPv6, IPv6 que não passa em `filter_var(..., FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)`, tailscale fora de `100.64.0.0/10` ou porta fora de 1–65535 → `400`.
  - Arquivos no servidor, fora do `public_html`: `~/gabs-remote/token.sha256` (só o SHA-256 do token) e `~/gabs-remote/presenca/<uuid>.json`.
  - Funções em `presenca_lib.php`: `presenca_token_ok(?string $authorization, string $hashSalvo): bool` (com `hash_equals`), `presenca_validar(array $corpo): ?string` (mensagem de erro ou `null`), `presenca_registro(array $corpo, string $remoteAddr, int $agora): array`.

- [ ] **Step 1: Testes que falham** em `testes.php` (script PHP puro, `assert` com `zend.assertions=1`, sai com código 1 na primeira falha):
  - `presenca_token_ok('Bearer abc', hash('sha256','abc'))` é `true`; `'Bearer abd'`, `null` e `'abc'` sem "Bearer" são `false`.
  - `presenca_validar` aceita o corpo do contrato; recusa uuid `"x"`, 9 IPv6, IPv6 `"1.2.3.4"`, tailscale `"192.168.0.1"`, porta `0`.
  - `presenca_registro($corpo, '177.10.20.30', 1700000000)` tem `ipv4 = '177.10.20.30'` e `atualizado = 1700000000`; com `remoteAddr` IPv6, `ipv4` fica ausente.
  Copiar para uma pasta temporária do servidor e rodar `ssh hostinger "php ~/gabs-remote-teste/testes.php"`: FAIL.
- [ ] **Step 2: Implementar `presenca_lib.php` e `presenca.php`.** O `presenca.php` só lê `~/gabs-remote/` (caminho resolvido por `dirname(__DIR__, n)` conforme a pasta do subdomínio, sem caminho fixo de usuário no código). Rodar os testes no servidor: PASS. Apagar `~/gabs-remote-teste/`.
- [ ] **Step 3: Publicar (com o ok do Gab).** O Gab cria no hPanel o subdomínio `remote.gabtavares.com` **sem CDN** (o `REMOTE_ADDR` tem de ser o IP real) com certificado Let's Encrypt; o Claude copia só `presenca.php` e `presenca_lib.php` para a pasta do subdomínio por `scp`; o Gab gera o token (`[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Max 256 }) -as [byte[]])`), grava o SHA-256 em `~/gabs-remote/token.sha256` e guarda o token no gerenciador de senhas ("Gabs Remote — presença"); `docs/segredos.md` ganha a linha (só o local, nunca o token).
- [ ] **Step 4: Verificar** do PC com `curl.exe`: `POST` com token certo → `200` e `ipv4` igual ao `curl.exe -4 https://ifconfig.me`; token errado → `401`; `GET` devolve o registro. Conferir que `https://gabtavares.com` e o Vagabs continuam respondendo.
- [ ] **Step 5: Commit** — `feat(web): presença do PC na hospedagem`.

### Task 5: Host publica os endereços e abre as portas de fora (só se a Task 1 achou caminho direto)

**Files:**
- Create: `host/src/gabs/presence.h`, `host/src/gabs/presence.cpp`, `host/tests/unit/gabs/test_presence.cpp`
- Modify: `host/cmake/compile_definitions/common.cmake`, `host/src/main.cpp` (iniciar a thread depois do `nvhttp` estar pronto)
- Modify: `tools/setup/instalar-host.ps1`, `tools/setup/instalar-host.Tests.ps1` (regras de internet)

**Interfaces:**
- Consumes: contrato da Task 4; `enumerate_ip_addresses()` (Task 2); `http::unique_id`.
- Produces (em `namespace gabs::presence`):
  - `struct config_t { std::string url; std::string token; };`
  - `std::optional<config_t> load_config(const std::filesystem::path &file);` — lê `<pasta de config>\gabs_presence.json` (`{"url": "...", "token": "..."}`); arquivo ausente, JSON inválido ou campo vazio → `std::nullopt` (presença desligada, sem erro).
  - `struct addresses_t { std::vector<std::string> ipv6; std::vector<std::string> tailscale; bool operator==(const addresses_t &) const = default; };`
  - `addresses_t select_addresses(const std::vector<network::ip_address_t> &all);` — IPv6 globais (`2000::/3`) não `deprecated` → `ipv6` (no máximo 8); IPv4 em `100.64.0.0/10` → `tailscale`; os dois ordenados e sem repetição.
  - `std::string make_body(const std::string &uuid, int port, const addresses_t &a, const std::string &version);`
  - Thread: confere os endereços a cada 30 s e manda o `POST` quando mudam ou a cada 5 min; `libcurl` com `CURLOPT_IPRESOLVE = CURL_IPRESOLVE_V4` (o servidor vê o IPv4 público) e timeout de 10 s; falha só loga `warning`, uma vez por sequência de falhas.
  - Regras novas em `Get-RegrasFirewall`: `Gabs Remote Internet TCP` (47984, 47989, 48010) e `Gabs Remote Internet UDP` (47998, 47999, 48000, 48002, 48010), perfil `Private`, `EnderecoRemoto` `Any`. Sem 47990 e sem 48100.

- [ ] **Step 1: Testes que falham:**
  - `Presence.SelectsGlobalIpv6AndTailscale`: entradas `2804:14d:1::5`, `fe80::1`, `fd7a:115c:a1e0::1`, `192.168.15.10`, `100.99.120.91`, `2804:14d:1::6` (deprecated) → `ipv6 == {"2804:14d:1::5"}`, `tailscale == {"100.99.120.91"}`.
  - `Presence.CapsIpv6AtEight`: 10 globais → 8.
  - `Presence.BodyMatchesContract`: `make_body` gera JSON com as chaves `uuid`, `porta`, `ipv6`, `tailscale`, `versao` e nada mais.
  - `Presence.ConfigMissingOrEmptyIsOff`: arquivo ausente, `{}` e `{"url":"x","token":""}` → `std::nullopt`.
  - Pester: `Get-RegrasFirewall` devolve 6 regras; as duas `Internet` não têm 47990 nem 48100.
  Rodar: FAIL.
- [ ] **Step 2: Implementar `presence.{h,cpp}`, a thread e as regras.** Rodar os testes: PASS.
- [ ] **Step 3: Configurar (o Gab):** grava `C:\Program Files\Gabs Remote\config\gabs_presence.json` com a URL e o token; se a Task 1 deu IPv4 público, liga `upnp = enabled` no painel (Configuração › Rede) para o host pedir o redirecionamento ao roteador (e as aberturas IPv6, se o roteador deixar); reinstala com `instalar-host.ps1` como administrador.
- [ ] **Step 4: Verificar:** `GET` da presença mostra os endereços do PC e `atualizado` recente; no log do host, as portas mapeadas pelo UPnP (se ligado); do 4G, `http://<ipv4-público>:47989/serverinfo` e/ou `http://[<ipv6>]:47989/serverinfo` respondem conforme a Task 1.
- [ ] **Step 5: Commit** — no submódulo `feat(network): presença do PC na hospedagem`; no principal `feat(tools): regras de firewall para acesso de fora` com o ponteiro.

### Task 6: Escolha automática do caminho no app

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/net/PathKind.java`, `Candidate.java`, `PathSelector.java`, `ParallelPathPoller.java`, `PresenceClient.java`
- Create: `android/app/src/test/java/com/limelight/gabs/net/PathKindTest.java`, `PathSelectorTest.java`, `ParallelPathPollerTest.java`, `PresenceClientTest.java`
- Modify: `android/app/src/main/java/com/limelight/computers/ComputerManagerService.java` (`parallelPollPc`, ~626–700), `nvstream/http/ComputerDetails.java` (dois campos), `utils/ServerHelper.java` (`createStartIntent`), `Game.java` (aviso do caminho e linha no overlay, `onPerfUpdate` ~3067), `res/xml/preferences.xml`, `values/strings.xml`, `values-pt-rBR/strings.xml`

**Interfaces:**
- Consumes: contrato da presença (Task 4), se existir.
- Produces (pacote `com.limelight.gabs.net`):
  - `enum PathKind { LAN, IPV6, IPV4_PUBLICO, TAILSCALE, MANUAL }`, nessa ordem de preferência; `String label()` = "Rede de casa", "IPv6 direto", "IPv4 (porta aberta)", "Tailscale", "Endereço manual"; `static PathKind classify(InetAddress a)`: `100.64.0.0/10` e `fd7a:115c:a1e0::/48` → `TAILSCALE`; IPv4 privado, link-local e IPv6 `fc00::/7`/`fe80::/10` → `LAN`; IPv6 global → `IPV6`; outro IPv4 → `IPV4_PUBLICO`.
  - `final class Candidate { final ComputerDetails.AddressTuple address; final PathKind kind; }` com `equals`/`hashCode` pelo endereço.
  - `PathSelector`: `TIE_MS = 10`; `static <T> ParallelPathPoller.Result<T> choose(List<ParallelPathPoller.Result<T>> ok)` — se houver `LAN`, a `LAN` de menor RTT; senão a de menor RTT, mas qualquer outra a até `TIE_MS` dela ganha se vier antes na ordem de `PathKind`; lista vazia → `null`. `static List<Candidate> filter(List<Candidate> all, PathKind forcedOrNull)`.
  - `ParallelPathPoller`: `interface Prober<T> { T probe(Candidate c) throws InterruptedException; }` (`null` = falhou); `static final class Result<T> { Candidate candidate; long rttMs; T value; }`; `static <T> Result<T> poll(List<Candidate> cs, Prober<T> p, long graceMs)` — uma thread por candidato, mede o RTT do `probe`; volta na hora se uma `LAN` responder; depois da primeira resposta espera no máximo `graceMs` (usar `800`) pelas outras; escolhe com `PathSelector.choose`; interrompe as que sobrarem.
  - `PresenceClient`: `static Info parse(String json)` (`null` se malformado), `Info { String ipv4; List<String> ipv6; List<String> tailscale; int porta; long atualizado; List<Candidate> candidates(long nowSec); }` (vazio se `atualizado` tiver mais de 24 h); `static Info fetch(String url, String token, String uuid)` com `HttpURLConnection`, timeout 3 s.
  - Preferências: `gr_presence_url` (padrão `https://remote.gabtavares.com/presenca.php`), `gr_presence_token` (vazio = desligado), `gr_force_path` (`AUTO` padrão, `IPV6`, `IPV4_PUBLICO`, `TAILSCALE`; para medir a Task 10).
  - Em `ComputerDetails`: `public PathKind grPathKind; public long grRttMs;` (copiados em `update`). Extras do `Game`: `EXTRA_GR_PATH` (nome do `PathKind`), `EXTRA_GR_RTT`, `EXTRA_GR_CANDIDATES` (`ArrayList<String>` no formato `kind|endereço|porta`, usado na Task 8).

- [ ] **Step 1: Testes JUnit que falham:**
  - `PathKindTest`: `100.99.120.91` → `TAILSCALE`; `fd7a:115c:a1e0::5` → `TAILSCALE`; `192.168.15.10` e `fe80::1` → `LAN`; `2804:14d::1` → `IPV6`; `177.10.20.30` → `IPV4_PUBLICO`.
  - `PathSelectorTest`: `LAN 40 ms` e `IPV6 5 ms` → `LAN`; `TAILSCALE 20` e `IPV6 28` → `IPV6` (empate de 10 ms); `TAILSCALE 20` e `IPV6 31` → `TAILSCALE`; `IPV4_PUBLICO 25` e `IPV6 30` → `IPV6`; vazio → `null`; `filter(todos, TAILSCALE)` só deixa os Tailscale.
  - `ParallelPathPollerTest` com `Prober` falso que dorme o tempo pedido: `lanFailureFallsBackToRemote` (LAN devolve `null`, Tailscale 30 ms → Tailscale); `lanReturnsImmediately` (LAN 10 ms e Tailscale 2000 ms → volta em menos de 500 ms com LAN); `slowCandidateDoesNotBlockChoice` (IPv6 30 ms e IPv4 que nunca volta → resposta em menos de `30 + 800 + 200` ms com IPv6); `allFailReturnsNull`.
  - `PresenceClientTest`: JSON do contrato → `ipv4`, 1 IPv6, 1 Tailscale e 3 candidatos com a porta; `parseRejectsMalformed` (`"{"`, `ipv6` que não é lista) → `null`; `atualizado` de 25 h atrás → sem candidatos.
  Rodar `build-android.ps1 -Testes`: FAIL.
- [ ] **Step 2: Implementar as cinco classes.** Rodar: PASS.
- [ ] **Step 3: Encaixar no upstream.**
  - `parallelPollPc`: monta os candidatos com os quatro endereços do upstream (nomes, como o MagicDNS, resolvidos para classificar; se não resolver, `MANUAL`) mais os da presença do `uuid` (guardados em memória, atualizados em segundo plano no máximo a cada 60 s e só com token configurado), aplica `filter` com `gr_force_path`, chama `ParallelPathPoller.poll(candidatos, c -> tryPollIp(details, c.address), 800)`, e grava `activeAddress`, `grPathKind` e `grRttMs`. A ordem fixa do upstream sai.
  - `ServerHelper.createStartIntent`: põe os três extras novos.
  - `Game`: no início da sessão, `Toast` "Conectado por <label> · <rtt> ms"; o overlay de desempenho ganha a linha "Caminho: <label>".
  - Configurações: categoria "Acesso de fora" com URL da presença, token (campo de senha) e "Forçar caminho".
- [ ] **Step 4: Verificar no tablet:** em casa, Toast "Rede de casa"; no Wi-Fi do escritório e no 4G, o caminho escolhido bate com a Task 1 (IPv6 ou IPv4 quando abertos, senão Tailscale); com o token apagado o app continua achando o PC pelo Tailscale; "Forçar caminho" = Tailscale funciona mesmo com IPv6 disponível.
- [ ] **Step 5: Commit** — no submódulo `feat(net): escolha automática do caminho e presença`; no principal o ponteiro.

### Task 7: Ligar o PC de casa e de fora

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/wake/WakeFlow.java`, `RemoteWake.java`, `WakeDialog.java`
- Create: `android/app/src/test/java/com/limelight/gabs/wake/WakeFlowTest.java`, `RemoteWakeTest.java`
- Modify: `android/app/src/main/java/com/limelight/PcView.java` (`doWakeOnLan` ~500 e o clique num PC desligado), `res/xml/preferences.xml`, `strings.xml` (os dois)

**Interfaces:**
- Consumes: mecanismo do WoL de fora (Task 1); MAC certo (Task 2).
- Produces (pacote `com.limelight.gabs.wake`):
  - `WakeFlow`: `TIMEOUT_MS = 180_000`; `void start(long nowMs)`; `Status onPoll(boolean pcOnline, long nowMs)` com `enum Status { WAITING, ONLINE, TIMEOUT }`; `long elapsedMs(long nowMs)`.
  - `RemoteWake`: `enum Method { NENHUM, URL, APP }`; preferências `gr_wake_method` (padrão conforme a Task 1), `gr_wake_url` (campo de senha: a URL pode carregar segredo), `gr_wake_app` (padrão `com.amazon.dee.app`); `static Method parse(String pref)` (inválido → `NENHUM`); `void trigger(Context c)`: `URL` faz um `GET` com timeout de 10 s fora da thread da UI; `APP` abre o app pelo `getLaunchIntentForPackage` e mostra o Toast "Dispare a rotina que liga o PC"; `NENHUM` não faz nada.
  - `WakeDialog`: `AlertDialog` "Ligando o PC… mm:ss" com botão Cancelar; ouve o `ComputerManagerListener` e, quando o PC fica online, fecha e abre a sessão do app que estava rodando (ou a área de trabalho) pelo `ServerHelper.doStart`.

- [ ] **Step 1: Testes que falham:**
  - `WakeFlowTest`: `start(0)`; `onPoll(false, 1000)` = `WAITING`; `onPoll(true, 45000)` = `ONLINE`; noutro fluxo `onPoll(false, 179999)` = `WAITING` e `timesOutAfterThreeMinutes`: `onPoll(false, 180000)` = `TIMEOUT`; depois de `TIMEOUT`, `onPoll(true, …)` continua `TIMEOUT`.
  - `RemoteWakeTest`: `parse("URL")` = `URL`, `parse("xyz")` e `parse(null)` = `NENHUM`.
  Rodar: FAIL.
- [ ] **Step 2: Implementar.** Rodar: PASS.
- [ ] **Step 3: Encaixar em `PcView`:** a ação de ligar manda o pacote mágico do upstream (rede de casa) **e** chama `RemoteWake.trigger`, depois abre o `WakeDialog`; tocar num PC desligado oferece "Ligar o PC". O aviso `wol_no_mac` do upstream só aparece se também não houver método remoto.
- [ ] **Step 4: Verificar:** em casa, PC desligado → "Ligar o PC" → a sessão abre sozinha; no 4G, o mesmo pelo método da Task 1 (anotar o tempo até a sessão); PC sem energia na tomada → o diálogo desiste em 3 min com "O PC não respondeu em 3 minutos."
- [ ] **Step 5: Commit** — no submódulo `feat(wake): ligar o PC de casa e de fora`; no principal o ponteiro.

### Task 8: Reconexão automática na troca de rede

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/session/ReconnectPolicy.java`, `Reconnector.java`
- Create: `android/app/src/test/java/com/limelight/gabs/session/ReconnectPolicyTest.java`, `SessionExitTest.java`
- Modify: `android/app/src/main/java/com/limelight/gabs/session/SessionExit.java`, `Game.java` (`connectionTerminated` ~2695, `onStop`/`gabsQuitHostApp` ~1476, registro de rede), `strings.xml` (os dois)

**Interfaces:**
- Consumes: `ParallelPathPoller`, `PathKind`, `EXTRA_GR_CANDIDATES`, `EXTRA_GR_PATH` (Task 6); decisão 0004.
- Produces:
  - `SessionExit.quitHostApp(boolean finishing, boolean connected, boolean reconnecting)` — `finishing && connected && !reconnecting`. A assinatura antiga sai (todas as chamadas passam a usar a nova).
  - `ReconnectPolicy`: `GIVE_UP_MS = 120_000`; `static boolean shouldReconnect(int errorCode, boolean userQuit)` — `false` se `userQuit`, `ML_ERROR_GRACEFUL_TERMINATION`, `ML_ERROR_PROTECTED_CONTENT` ou `ML_ERROR_FRAME_CONVERSION`; `true` nos outros; `static long nextDelayMs(int attempt, long elapsedMs)` — esperas 0, 1000, 2000, 4000, 8000 e depois 15000 por tentativa; `-1` quando `elapsedMs + espera > GIVE_UP_MS`; `static boolean restartOnNetworkChange(PathKind active)` — `false` só para `TAILSCALE` (o túnel sobrevive à troca de rede; espera a queda real).
  - `Reconnector`: roda as tentativas numa thread; cada uma refaz o `ParallelPathPoller.poll` com os candidatos do extra e um `Prober` que chama `NvHTTP.getServerInfo` e confere o `uuid`; achou → reabre o `Game` com o mesmo `Intent`, `EXTRA_HOST`/`EXTRA_PORT`/`EXTRA_GR_PATH` novos, e termina o atual com `reconnecting = true`.

- [ ] **Step 1: Testes que falham:**
  - `SessionExitTest`: `quitHostApp(true, true, false)` = `true`; `reconnectDoesNotQuitHostApp`: `quitHostApp(true, true, true)` = `false`; `quitHostApp(false, true, false)` = `false`.
  - `ReconnectPolicyTest`: `shouldReconnect(ML_ERROR_NO_VIDEO_TRAFFIC, false)` = `true`; `(ML_ERROR_GRACEFUL_TERMINATION, false)` = `false`; `(-1, true)` = `false`; `nextDelayMs(0, 0)` = 0, `(3, 5000)` = 4000, `(7, 60000)` = 15000, `(7, 110000)` = -1; `restartOnNetworkChange(TAILSCALE)` = `false`, `(IPV6)` = `true`, `(LAN)` = `true`.
  Rodar: FAIL.
- [ ] **Step 2: Implementar `ReconnectPolicy`, `Reconnector` e a nova assinatura.** Rodar: PASS.
- [ ] **Step 3: Encaixar em `Game.java`:**
  - `connectionTerminated`: se `shouldReconnect(errorCode, usuárioSaiu)`, em vez do diálogo do upstream, aviso no overlay de notificação "Reconectando… (tentativa N)" e `Reconnector`; se desistir, diálogo "A conexão caiu e não voltou em 2 minutos. O PC continua pronto: abra a sessão de novo quando a rede voltar."
  - Durante a sessão, `registerDefaultNetworkCallback`: quando a rede padrão passa a ser outra e `restartOnNetworkChange(caminho atual)`, para a conexão em silêncio e chama o `Reconnector` sem esperar os ~10 s do upstream.
  - `gabsQuitHostApp` usa a assinatura nova com o estado `reconnecting`.
- [ ] **Step 4: Verificar no tablet** (com o host em serviço e o log aberto): sessão pelo Wi-Fi de casa, desligar o Wi-Fi → reabre pelo 4G sozinha, o log mostra `reusing the virtual display` e nenhum `/cancel`; voltar ao Wi-Fi → reabre pela rede de casa; pelo Tailscale, a troca de rede segura a sessão ou reconecta; modo avião por 3 min → diálogo de desistência, e o PC continua pronto (decisão 0004).
- [ ] **Step 5: Commit** — no submódulo `feat(session): reconexão automática na troca de rede`; no principal o ponteiro.

### Task 9: Clique até a imagem ≤ 30 ms em casa

**Files:**
- Modify: `docs/testes/fase-3-checklist.md` (rascunho, tabela de ajustes)
- Modify (só o que for adotado): `C:\Program Files\Gabs Remote\config\sunshine.conf` pelo painel e o padrão da preferência no app (`PreferenceConfiguration.java`)

**Interfaces:**
- Consumes: medidor da fase 2 (`docs/latencia.md`), correção da Task 3.
- Produces: o conjunto de ajustes adotado e a medida final (clique a 120 fps, Nativo 100%, em casa).

Linha de base: 32,0 ms de média (p95 39). Cada medida: Clique, 40 amostras, repetida duas vezes; vale a média das duas.

- [ ] **Step 1: Medir de novo a linha de base** com o host da Task 3.
- [ ] **Step 2: Testar um ajuste por vez**, voltando ao anterior se não melhorar pelo menos 1 ms ou se o Gab notar piora de imagem: (a) no app, "Ritmo dos quadros" (frame pacing do upstream) em "menor latência"; (b) no host, `nvenc_preset = 1` (o mais rápido); (c) no host, `nvenc_twopass = disabled`; (d) bitrate 50 → 80 Mbps. Anotar cada linha na tabela.
- [ ] **Step 3: Adotar** o melhor conjunto (padrão no app, se for preferência; `sunshine.conf` do Gab, se for do host) e medir o carimbo também. Se ficar acima de 30 ms, anotar a distância e o que mais pesa (decodificação, rede, host) para a fase 7, sem bloquear a fase.
- [ ] **Step 4: Commit** — no submódulo do app, se mudou o padrão, `perf: <ajuste> por padrão`; no principal o rascunho do checklist.

### Task 10: Medição fora de casa, checklist e fechamento

**Files:**
- Modify: `docs/testes/fase-3-checklist.md` (rascunho das Tasks 3 e 9)
- Create: `docs/testes/fase-3-latencia/` (CSVs)
- Modify: `docs/tailscale.md` (o app acha o PC sozinho), `docs/rede-fora.md`, `docs/sessoes.md`, `CLAUDE.md` (módulos novos: `host/src/gabs/network.*`, `presence.*`, `android/.../gabs/net/`, `gabs/wake/`, `web/presenca/`, `tools/setup/conferir-wol.ps1`), `graphify-out/`

- [ ] **Step 1: Medir fora** no Wi-Fi do escritório (e no 4G, se der), Nativo 100% a 120 fps, para cada caminho disponível (usar "Forçar caminho"): caminho e RTT do Toast; no Tailscale, direto ou DERP (`tailscale status` no PC); fps recebidos/renderizados, quadros perdidos, latência de rede; medidor (clique e carimbo: média, p95, perdidos); e se o uso é bom para trabalho com 50 Mbps (critério 1). Mesmo teste, ao mesmo tempo, com o Acesso Remoto do Google, à mão.
- [ ] **Step 2: Sessão estável no 4G/5G**: 15 min de uso real (VS Code, navegador) sem queda que não volte sozinha; anotar quantas reconexões houve.
- [ ] **Step 3: Escrever `docs/testes/fase-3-checklist.md`** com cada item da linha da fase 3 (§10), ✓/✗ e evidência: critério 1 medido fora; escolha automática (cada caminho e o Toast); presença (se feita); WoL de casa e de fora; reconexão (Task 8 Step 4); 10022 resolvido; MAC pelo Tailscale; ajustes de latência; Review Focus 1–5.
- [ ] **Step 4: Atualizar** `docs/tailscale.md`, `CLAUDE.md`, o grafo (`/graphify . --update`) e `docs/sessoes.md` (fase 3 feita, estado ao fechar, prompt da fase 4).
- [ ] **Step 5: Commit** — `docs: checklist e fechamento da fase 3`. Push dos submódulos e do principal só com o ok do Gab.

---

## Fora deste plano
- Relay próprio (TURN/VPS): sem VPS (spec §5.2 item 4).
- Notificação no PC e log de acessos (§5.4): o Gab mora sozinho; fica para a fase 7 se ele pedir.
- Tela virtual que some com o host rodando (registro em memória preso até reiniciar o serviço): raro, documentado no checklist da fase 2.
- Teclado pt-BR que fica no PC quando o host cai no meio da sessão: minor adiado da fase 2.

## Próxima sessão

Para **executar este plano**, comece uma sessão nova e use:

> Gabs Remote — executar o plano `docs/superpowers/plans/2026-11-07-fase-3-fora-de-casa.md`. Leia o `CLAUDE.md`, o plano e as decisões em `docs/decisoes/`. Execução nativa (executing-plans), pedindo meu ok nos passos marcados (roteador, firewall, serviço, hospedagem, token, push). A Task 1 precisa de mim no tablet e no app Alexa. Ao terminar, atualize `docs/sessoes.md`, rode `/graphify . --update` e me dê o prompt da próxima sessão.

Se a execução parar no meio:

> Gabs Remote — continuar a execução de `docs/superpowers/plans/2026-11-07-fase-3-fora-de-casa.md`. Leia o `CLAUDE.md`, confira no `git log` (principal e submódulos) e nos checkboxes o que já foi feito e siga da próxima tarefa.

Depois da fase 3 executada, o plano da **fase 4 (Atualização e CI)** usa:

> Gabs Remote — escrever o plano da **fase 4 (Atualização e CI)**. Leia o `CLAUDE.md`, a spec `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§8 Atualização automática, §9.1, §10 linha da fase 4), `docs/decisoes/` (a 0002 trava o `applicationId`), `docs/segredos.md`, `docs/testes/fase-3-checklist.md` e `graphify-out/GRAPH_REPORT.md`. Use o graphify para achar nos forks o build, a versão e o painel do host. Escreva com a skill writing-plans, terminando com a seção "Próxima sessão".
