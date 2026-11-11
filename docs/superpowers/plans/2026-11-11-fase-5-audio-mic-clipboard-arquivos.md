# Fase 5 — Áudio, microfone, clipboard e arquivos: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O som do PC toca no tablet com as caixas do PC em silêncio, o microfone do tablet vira um microfone do Windows, o clipboard (texto e imagem) passa nos dois sentidos, arquivos vão do tablet para o PC e do PC para o tablet com progresso e retomada, e o tablet manda o PC bloquear, suspender, reiniciar ou desligar (critério 5, sem a câmera), entregue em três Releases (0.5.0, 0.5.1, 0.5.2) pelo fluxo da decisão 0006.

**Architecture:** Nada muda no `moonlight-common-c` (é submódulo do upstream nos dois forks). O **microfone** tem transporte próprio: o app captura com `AudioRecord` (fonte `VOICE_COMMUNICATION`, com o cancelamento de eco do Android), codifica em Opus pelo `libopus` que o `moonlight-core` já linka, cifra cada quadro em AES-GCM com a `rikey` da sessão e manda por UDP para a porta 48002 do PC (já liberada nas regras `Gabs Remote LAN/Tailscale UDP` desde a fase 3); o host (`host/src/gabs/mic.*`) decifra, reordena num buffer curto, decodifica e escreve por WASAPI na entrada de um cabo de áudio virtual, cuja saída o Windows vê como microfone. **Clipboard, arquivos e ações** são rotas HTTPS novas no `nvhttp` (porta 47984, autenticadas pelo certificado do pareamento, como o `/gabs/cursor` da 0.4.1): long poll para o que vem do PC, `POST`/`PUT` para o que vai do tablet. O host conta o que sabe fazer num campo novo do `/serverinfo` (`GabsFeatures`), e o app só mostra o que o host suporta.

**Tech Stack:** C++23 + GoogleTest + OpenSSL 3 (`crypto::cipher::gcm_t`) + libopus + WASAPI + WIC + Simple-Web-Server do upstream (host, MSYS2 UCRT64); Java 17 + JUnit 4 + OkHttp + `AudioRecord`/`ClipboardManager`/`MediaStore` + JNI em C (app); PowerShell 5.1 + Pester 5 (scripts); NSIS (instalador).

**Spec:** `docs/superpowers/specs/2026-11-06-gabs-remote-design.md` (§1.1 critério 5 sem a câmera, §4.1 H3/H5/A3, §6.3, §6.5, §10 linha da fase 5, §11 risco "Drivers no Windows 10"). Decisões: 0004 (PC pronto com o app em segundo plano), 0005 (nenhuma porta nova para a internet), 0006 (Release). Como publicar: `docs/release.md`.

## Decisões deste plano (o Gab confirma ao revisar; viram a decisão 0007 na Task 1)
1. **Transporte próprio do microfone, sem mexer no `moonlight-common-c`.** As propostas do upstream (moonlight-common-c#123 do Foundation, #173 para o GameStream da NVIDIA) não estão mergeadas nem combinam entre si; adotar uma delas obrigaria um terceiro fork. UDP 48002, um quadro Opus por pacote, cifrado com a chave da sessão. Se um dia o upstream tiver microfone, a troca fica contida em `gabs/mic`.
2. **Driver do microfone: VB-CABLE** (VB-Audio, assinado, "CABLE Input" → "CABLE Output"), salvo se a Task 1 mostrar que o Virtual-Audio-Driver da VirtualDrivers aceita áudio de fora no microfone. O microfone desse driver vem do exemplo Sysvad e não tem entrada (a spec supunha que tinha). O VB-CABLE é *donationware* e não pode ir dentro do instalador: um script baixa o pacote oficial com SHA-256 fixo e instala uma vez, com o ok do Gab.
3. **Caixas do PC em silêncio** pela opção do upstream "Tocar som no PC" (desligada), que precisa de um alto-falante virtual para o host trocar o padrão durante a sessão: "Steam Streaming Speakers" se o Steam estiver instalado; senão o alto-falante do Virtual-Audio-Driver 25.7.14 (assinado pela SignPath, MIT, pode ir no instalador). O nome escolhido vira o padrão de `virtual_sink` no host.
4. **Microfone começa mudo em toda sessão.** O Gab liga pelo menu da sessão; a preferência "Microfone ligado ao conectar" (desligada) muda isso. O indicador é o ponto verde do próprio Android (aparece só com o `AudioRecord` aberto) mais o texto do item do menu. Com o app em segundo plano (decisão 0004) o microfone **para**.
5. **Clipboard automático por padrão** (preferência "Clipboard automático", ligada), só durante a sessão, com limite de 1 MiB de texto e 16 MiB de imagem PNG. Desligado, o menu da sessão tem "Mandar clipboard ao PC" e "Trazer clipboard do PC".
6. **Arquivos sem sessão aberta do lado do tablet:** "Enviar para o PC" (compartilhar do Android) funciona com o PC ligado e pareado, em segundo plano, para `Downloads\Gabs Remote` do usuário logado. "Enviar para o tablet" (Enviar para do Explorer) põe o arquivo numa fila; o app busca a fila enquanto a sessão está aberta e salva em `Download/Gabs Remote` do tablet.
7. **Ações remotas** pelo menu da sessão: bloquear, suspender, reiniciar e desligar (desligar completo, sem o Início rápido, por causa do WoL). As três últimas pedem confirmação.

## Global Constraints
- Docs, notas de versão, UI e mensagens em **pt-BR**; código e identificadores em inglês. Toda mudança em arquivo do upstream leva `// Gabs Remote:` (ou `<!-- Gabs Remote: -->` em XML). Código novo em `host/src/gabs/`, `host/src/platform/windows/gabs/`, `android/.../com/limelight/gabs/`, testes em `host/tests/unit/gabs/` e `android/app/src/test/java/com/limelight/gabs/`.
- **Todo build por `C:\gr`.** Host: `powershell -File C:\gr\tools\build\build-host.ps1 [-Testes] [-Jobs 8]` (nunca mais de 8 jobs); testes `C:\gr\host\build\tests\test_sunshine.exe --gtest_filter=<Suite>.*`. App: `powershell -File C:\gr\tools\build\build-android.ps1 [-Testes] [-Release] [-Instalar]`. Pester: `Invoke-Pester C:\gr\<caminho>.Tests.ps1`.
- Scripts `.ps1` em UTF-8 **com BOM**. Com o serviço `GabsRemote` rodando, pare-o antes de testar o `sunshine.exe` do build em console.
- **Nenhuma porta nova** (decisão 0005): o microfone usa a UDP 48002, que já está em `$PortasUdp` de `installer/configurar-host.ps1`; as rotas novas usam a 47984. Conferir que nada no host abre outra.
- Rotas novas do `nvhttp` só na porta HTTPS, com o certificado do cliente pareado, como `/gabs/cursor`. Clipboard e fila de envio só respondem com sessão ativa (`rtsp_stream::session_count() > 0`), senão `409`.
- O host roda como SYSTEM na sessão do console. Tudo o que lê ou grava arquivo do usuário (Downloads, fila de envio, arquivo a enviar) faz isso **impersonando o usuário logado** (`retrieve_users_token(false)` + `impersonate_current_user`, de `platform/windows/misc.cpp`, a expor em `misc.h`), para o Windows aplicar as permissões dele.
- Interface nova no app só com componentes padrão (menu da sessão `gabs/input/SessionMenu`, `AlertDialog`, `Toast`, notificação, preferências do upstream); layout próprio é da fase 7.
- `applicationId` `com.gabtavares.gabsremote` (decisão 0002). Permissões novas no manifesto: `RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`.
- **Releases pelo fluxo de `docs/release.md`** (decisão 0006): o Claude faz commit, push, tag, rascunho e publicação sem pedir; o Gab digita a senha da chave do manifesto. `minApp` e `minHost` continuam `0.4.0` (o que é novo se liga pelo `GabsFeatures`).
- Instalar driver, mexer no serviço ou no firewall: o Gab roda como administrador, com o ok dele (o Claude prepara o comando).
- Commits com `gabavares <43415454+gabavares@users.noreply.github.com>` e `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Submódulo primeiro, depois o principal com o ponteiro.

## Formatos (todas as tasks usam estes)

**`GabsFeatures` no `/serverinfo`:** palavras separadas por espaço, em qualquer ordem: `mic`, `clipboard`, `files`, `actions`. Host sem o campo = nenhuma.

**Pacote do microfone (UDP, app → host:48002):**
```
0   4  magic "GRM1" (0x47 0x52 0x4D 0x31)
4   4  seq, uint32 little-endian, começa em 0 por conexão e nunca repete na mesma conexão (mudo e volta continua a contagem)
8  16  tag do AES-128-GCM
24  n  quadro Opus cifrado (1 ≤ n ≤ 1000)
```
Chave = `rikey` da sessão (16 bytes). IV de 12 bytes = `seq` em little-endian nos bytes 0–3, zeros nos bytes 4–9, `iv[10] = 'C'` (cliente), `iv[11] = 'M'` (microfone), seguindo a convenção do `stream.cpp` (`'C','C'` controle, `'H','C'`, `'V'`). Sem AAD: trocar o `seq` troca o IV e a tag falha. Opus: 48 kHz, mono, quadros de 20 ms (960 amostras), 32 kbps, `OPUS_APPLICATION_VOIP`, FEC dentro da banda ligado com perda esperada de 10%.

**Vetor de teste do pacote** (o mesmo no host e no app): chave `000102030405060708090a0b0c0d0e0f`, `seq = 7`, Opus `"gabs"` (4 bytes ASCII). O pacote esperado (hex) é gerado uma vez na Task 3 com o OpenSSL do host, anotado em `host/tests/unit/gabs/testdata/mic-packet.hex` e copiado literalmente para o teste do app na Task 5.

**Clipboard (`/gabs/clipboard`):**
- `GET /gabs/clipboard?v=<versão que o app tem>`: long poll de até 10 s. Mudou (ou a versão do app é outra) → `200`, cabeçalho `X-Gabs-Clip-Version: <n>`, `Content-Type: text/plain; charset=utf-8` ou `image/png`, corpo = conteúdo. Nada mudou → `304` com `X-Gabs-Clip-Version`. Clipboard do PC vazio, de outro formato ou grande demais → `204` com a versão.
- `POST /gabs/clipboard` com `Content-Type` `text/plain; charset=utf-8` ou `image/png` → `200` com `X-Gabs-Clip-Version` da escrita; `413` acima do limite; `415` outro tipo; `409` sem sessão.

**Arquivos (`/gabs/files`):**
- Tablet → PC: `PUT /gabs/files/in?id=<32 hex>&name=<nome, URL-encoded>&size=<bytes>&offset=<bytes>` com um pedaço de até 8 MiB no corpo → `200 received=<n>`; offset diferente do que o host tem → `409 received=<n>` (o app recomeça de `n`); terminou → `200 done=<nome final>`; disco cheio → `507`; nome ou tamanho inválido → `400`. `GET /gabs/files/in?id=<id>` → `200 received=<n>` (`0` se não conhece). Parciais em `Downloads\Gabs Remote\.parcial\<id>.part` + `<id>.json` (`name`, `size`); com o tamanho completo, vira `Downloads\Gabs Remote\<nome>` (ou `<nome> (2).<ext>`...). Parciais com mais de 7 dias são apagados na subida do host. Limite: 64 GiB por arquivo.
- PC → tablet: `gabs-enviar.exe <arquivos...>` grava `%LOCALAPPDATA%\Gabs Remote\enviar\<uuid>.txt` (um caminho completo por linha, UTF-8; pastas são ignoradas). `GET /gabs/files/out` → `200`, uma linha por arquivo pendente: `<id> <tamanho> <nome URL-encoded>`. `GET /gabs/files/out/<id>` com `Range: bytes=<início>-` opcional → `206`/`200` com o conteúdo, lido em pedaços (nunca o arquivo inteiro na memória). `DELETE /gabs/files/out/<id>` → `204` (sai da fila). Arquivo apagado ou movido no PC → some da lista.

**Ações (`/gabs/action`):** `POST /gabs/action?do=lock|sleep|restart|shutdown` → `202` e a ação acontece 1 s depois (a resposta chega antes); outro valor → `400`.

## Review Focus
1. **Eco e retorno no microfone:** som do PC saindo pelo alto-falante do tablet e voltando pelo microfone; ou o "CABLE Input" virando a saída padrão do Windows e o host capturando o próprio microfone para o tablet. Esperado: o app usa `VOICE_COMMUNICATION` (+ `AcousticEchoCanceler` quando existir); o host recusa escrever no microfone virtual se ele for o dispositivo que está capturando o som da sessão, e loga o motivo. Testes `MicSink.RefusesCaptureEndpoint` (Task 4) e `MicCaptureConfigTest.usesVoiceCommunication` (Task 5).
2. **Rede ruim no 4G pelo Tailscale:** pacotes perdidos, fora de ordem, duplicados, atrasados ou forjados. Esperado: perda vira o FEC ou a ocultação do Opus, nada de estalo nem atraso crescente (o buffer descarta o que passa de 120 ms), duplicado e repetido são ignorados, pacote que não decifra é descartado sem log a cada pacote. Testes `MicReceiver.*` (Task 3).
3. **App em segundo plano, sessão encerrada ou queda de rede com o microfone ligado** (decisão 0004 e reconexão da fase 3). Esperado: o tablet para de gravar ao sair da tela da sessão (o ponto verde some); o host entrega silêncio ao microfone virtual quando os pacotes param e solta o dispositivo no fim da sessão; ao reconectar, o microfone volta no estado de antes (mudo/ligado) com `seq` novo e chave nova. Testes `MicReceiver.SilenceWhenPacketsStop` (Task 3), `MicControllerTest.stopsInBackground` e `MicControllerTest.keepsStateAcrossReconnect` (Task 5).
4. **Clipboard em laço ou gigante:** a escrita vinda do tablet volta como "mudança do PC" e fica pingando; imagem de 80 MB ou texto de 5 MB copiado no PC. Esperado: o que um lado acabou de escrever não volta; acima do limite não passa, e o app avisa uma vez por cópia ("Clipboard grande demais; use Enviar arquivo"). Testes `ClipboardTracker.IgnoresOwnWrite`, `ClipboardTracker.OversizeIsEmpty` (Task 7), `ClipboardSyncTest.noEcho` e `ClipboardSyncTest.oversizeWarnsOnce` (Task 8).
5. **Nomes e transferências hostis ou interrompidas:** nome `..\..\Windows\x.dll`, `CON.txt`, `a:b?.png`, nome repetido, emoji; Wi-Fi caindo no meio de um envio de 2 GB; disco cheio; arquivo da fila que o usuário não pode ler (o host é SYSTEM). Esperado: nome limpo dentro de `Downloads\Gabs Remote`, nunca fora; repetido ganha ` (2)`; o envio continua do ponto em que parou; disco cheio dá erro claro no tablet e apaga o parcial; arquivo sem permissão do usuário não é enviado. Testes `FileNames.*`, `UploadStore.*` (Task 10), `UploadTaskTest.resumesFromHostOffset` (Task 11); item manual da permissão na Task 10.

---

### Task 1: Decisão 0007 e drivers de áudio

**Files:**
- Create: `docs/decisoes/0007-audio-microfone-clipboard-arquivos.md`, `tools/setup/instalar-audio.ps1`, `tools/setup/instalar-audio.Tests.ps1`, `drivers/virtual-audio/` (só se o alto-falante do Virtual-Audio-Driver for o escolhido: INF, CAT, SYS e `README.md` com os SHA-256, como `drivers/sudovda/`)
- Modify: spec §4.1 H3 e §11 (driver escolhido), `installer/configurar-host.ps1` + `.Tests.ps1` (instala o alto-falante virtual se for o do pacote e o dispositivo não existir, só na instalação, como o SudoVDA), `installer/gabs-remote.nsi` (copiar `drivers\virtual-audio`), `docs/ambiente.md`

**Interfaces:**
- Produces: o nome do endpoint de saída que alimenta o microfone (`CABLE Input` se for o VB-CABLE) e o nome do alto-falante virtual para `virtual_sink` (Tasks 2 e 4).

- [ ] **Step 1: Conferir o Virtual-Audio-Driver** (`github.com/VirtualDrivers/Virtual-Audio-Driver`, release 25.7.14): no código, de onde o microfone tira as amostras. Regra: se houver um caminho para outro processo escrever no microfone (pipe, memória compartilhada, IOCTL), ele substitui o VB-CABLE; senão, VB-CABLE. Anotar o arquivo e a linha que provam.
- [ ] **Step 2: Levantar os dispositivos do PC:** `Get-PnpDevice -Class AudioEndpoint | Select FriendlyName, Status`. Se "Steam Streaming Speakers" existir, ele é o `virtual_sink`; senão, o alto-falante do Virtual-Audio-Driver 25.7.14 (conferir assinatura com `Get-AuthenticodeSignature` e anotar os SHA-256).
- [ ] **Step 3: Escrever o teste Pester** `instalar-audio.Tests.ps1`: `Test-PacoteVbCable` aceita só o zip com o SHA-256 fixo e recusa outro; `Get-PassosInstalacao` não lista nada quando os dispositivos já existem; o script recusa rodar sem administrador (código 2) e de caminho com espaço (código 2).
- [ ] **Step 4: Rodar e ver falhar.** `Invoke-Pester C:\gr\tools\setup\instalar-audio.Tests.ps1` → FAIL (script não existe).
- [ ] **Step 5: Escrever `instalar-audio.ps1`:** baixa o pacote oficial do VB-CABLE de `vb-audio.com/Cable/` (URL da versão atual e SHA-256 conferidos nesta task e fixados no script) para `%TEMP%\gabs-remote-vbcable\`, confere o hash, extrai, roda `VBCABLE_Setup_x64.exe -i -h`, e depois confere que "CABLE Input" existe e que a **saída padrão do Windows não mudou** (se mudou, volta a anterior). Instala também o alto-falante virtual do Step 2, se for o do pacote e não existir.
- [ ] **Step 6: Rodar os testes** → PASS. Depois, com o ok do Gab, ele roda o script como administrador; conferir em `mmsys.cpl` "CABLE Output" em Gravação e a saída padrão intacta.
- [ ] **Step 7: Escrever a decisão 0007** com as sete decisões do topo deste plano, a prova do Step 1, os hashes e as consequências (VB-CABLE não vai no instalador; reinstalar o Windows = rodar `instalar-audio.ps1` de novo; o nome no Windows fica "CABLE Output (VB-Audio Virtual Cable)"). Ajustar a spec §4.1 H3 e §11 citando a 0007.
- [ ] **Step 8: Commit** — `feat(setup): drivers de áudio do microfone e do silêncio do PC (decisão 0007)`.

### Task 2: Som do PC no tablet e caixas do PC em silêncio

**Files:**
- Modify: `host/src/config.cpp` (padrão de `audio.virtual_sink` = nome da Task 1, `// Gabs Remote:`), `android/app/src/main/res/values-pt-rBR/strings.xml` (só se "Tocar som no PC" não estiver traduzido)

**Interfaces:**
- Consumes: nome do alto-falante virtual (Task 1).

Sem teste unitário: é a troca de um valor padrão; o upstream já testa o uso do `virtual_sink`, e a prova é o teste ao vivo.

- [ ] **Step 1: Mudar o padrão** de `virtual_sink` em `config.cpp`; um `virtual_sink` escrito no `sunshine.conf` continua valendo.
- [ ] **Step 2: Build e suíte** `-Testes`: tudo verde como antes.
- [ ] **Step 3: Conferir em casa** (serviço parado, build em console): sessão com "Tocar som no PC" desligado → vídeo do YouTube no PC soa no tablet e **não** nas caixas, e o log mostra a troca para o alto-falante virtual; ao desconectar, a saída padrão volta a ser a de antes. Com a opção ligada, toca nos dois. Anotar no rascunho de `docs/testes/fase-5-checklist.md`, seção "Som do PC".
- [ ] **Step 4: Commit** (host, depois principal) — `feat(gabs): caixas do PC em silêncio durante a sessão`.

### Task 3: Host — receptor do microfone

**Files:**
- Create: `host/src/gabs/mic.h`, `host/src/gabs/mic.cpp`, `host/tests/unit/gabs/test_mic.cpp`, `host/tests/unit/gabs/testdata/mic-packet.hex`
- Modify: `host/cmake/compile_definitions/common.cmake` (fontes novas)

**Interfaces:**
- Produces (namespace `gabs::mic`):
  - `struct packet_t { std::uint32_t seq; std::vector<std::uint8_t> opus; };`
  - `std::optional<packet_t> open_packet(std::string_view datagram, const crypto::aes_t &key);` — confere magic, tamanho (24 + 1..1000) e tag; `nullopt` em qualquer falha.
  - `std::vector<std::uint8_t> seal_packet(std::uint32_t seq, std::string_view opus, const crypto::aes_t &key);` — o inverso (para testes e para conferir o app).
  - `class jitter_t { public: explicit jitter_t(std::chrono::milliseconds target = 60ms, std::chrono::milliseconds max = 120ms); void push(packet_t p, std::chrono::steady_clock::time_point now); std::optional<frame_t> pop(std::chrono::steady_clock::time_point now); };` com `struct frame_t { enum class kind_e { normal, fec, conceal, silence } kind; std::vector<std::uint8_t> opus; };` — `pop` devolve um quadro a cada 20 ms: o pacote esperado (`normal`), o seguinte para recuperar pela FEC (`fec`), ocultação (`conceal`, até 5 seguidos) ou `silence` (sem pacotes há mais de 200 ms). Descarta duplicados, `seq` já tocado e o que deixa o buffer acima de `max`.
  - `class decoder_t { public: decoder_t(); std::array<std::int16_t, 960> decode(const frame_t &f); };` — libopus 48 kHz mono; `fec` usa `decode_fec = 1`, `conceal` passa `nullptr`, `silence` devolve zeros.

- [ ] **Step 1: Gerar o vetor de teste** com `seal_packet` (escrito primeiro só para isso), conferir com um programa avulso de poucas linhas que usa `EVP_aes_128_gcm` direto (mesma chave, IV e entrada) e gravar em `testdata/mic-packet.hex`.
- [ ] **Step 2: Escrever os testes:**
  - `MicPacket.OpensTestVector`: `open_packet(hex do arquivo, chave 00..0f)` → `seq == 7`, `opus == "gabs"`.
  - `MicPacket.RejectsWrongKeyMagicTagAndSize`: chave trocada, magic `GRM2`, um bit da tag trocado, 24 bytes sem Opus, Opus de 1001 bytes → `nullopt`.
  - `MicPacket.SeqIsBoundToIv`: trocar o `seq` do cabeçalho de um pacote válido → `nullopt`.
  - `MicReceiver.InOrder`: 10 pacotes em ordem, `pop` a cada 20 ms → 10 `normal`.
  - `MicReceiver.ReordersWithinTarget`: chegam 1,3,2 em 5 ms → saem 1,2,3 `normal`.
  - `MicReceiver.LossUsesFecThenConceal`: falta o 5 e o 6 chega → o 5 sai `fec`; faltam 5 a 7 → `conceal`,`conceal`,`conceal`.
  - `MicReceiver.DropsDuplicateAndLate`: o 4 repetido e o 2 depois de tocado não saem de novo.
  - `MicReceiver.CapsDelay`: rajada de 20 pacotes de uma vez → o buffer joga fora os mais velhos e o atraso fica ≤ 120 ms.
  - `MicReceiver.SilenceWhenPacketsStop`: 250 ms sem pacotes → `silence`; volta a `normal` quando chegam de novo, sem esperar o `seq` antigo.
  - `MicDecoder.SilenceIsZeros` e `MicDecoder.DecodesEncodedTone`: tom de 440 Hz codificado pelo `opus_encode` → decodificado com energia na faixa certa.
- [ ] **Step 3: Rodar e ver falhar** (`--gtest_filter=Mic*`).
- [ ] **Step 4: Implementar** `mic.h`/`mic.cpp` (decifrar com `crypto::cipher::gcm_t` e IV de 12 bytes conforme "Formatos").
- [ ] **Step 5: Rodar** → PASS (`Mic*` e o resto do `Gabs*`).
- [ ] **Step 6: Commit** — `feat(gabs): pacote, buffer e decodificação do microfone do tablet`.

### Task 4: Host — microfone virtual na sessão

**Files:**
- Create: `host/src/platform/windows/gabs/mic_sink_win.cpp`, `host/src/gabs/mic_service.h`, `host/src/gabs/mic_service.cpp`, `host/src/gabs/features.h`, `host/src/gabs/features.cpp`
- Modify: `host/src/stream.cpp` (início e fim da sessão), `host/src/nvhttp.cpp` (`GabsFeatures` no `/serverinfo`), `host/src/config.cpp` (`gr_mic_sink`, padrão do nome da Task 1), `host/cmake/compile_definitions/{common,windows}.cmake`
- Test: `host/tests/unit/gabs/test_mic.cpp` (suítes `MicSink`, `MicService`), `host/tests/unit/gabs/test_features.cpp`

**Interfaces:**
- Consumes: `gabs::mic::open_packet`, `jitter_t`, `decoder_t` (Task 3).
- Produces:
  - `std::string gabs::features();` em `gabs/features.h` (cada task acrescenta a sua palavra em `features.cpp`): agora `"mic"`.
  - `class gabs::mic::service_t { public: explicit service_t(std::unique_ptr<sink_t> sink, std::uint16_t port = 48002); void begin(const crypto::aes_t &rikey); void end(); };` — `begin` abre o socket UDP (todas as interfaces, como o resto do host; o firewall restringe a LAN e Tailscale) e a thread que recebe, reordena e entrega 20 ms por vez ao `sink_t`; `end` fecha tudo e solta o dispositivo. Pacote de outra chave é ignorado; o endereço de origem pode mudar no meio (troca de rede).
  - `class gabs::mic::sink_t { public: virtual ~sink_t() = default; virtual bool open() = 0; virtual void write(std::span<const std::int16_t> pcm48k_mono) = 0; virtual void close() = 0; };` e `std::unique_ptr<sink_t> make_platform_sink(const std::string &endpoint_name);` (WASAPI compartilhado, 48 kHz, converte mono → formato do endpoint).
  - `std::optional<std::string> choose_mic_sink(const std::vector<endpoint_t> &render_endpoints, const std::string &wanted, const std::string &capture_endpoint_id);` com `struct endpoint_t { std::string id; std::string name; };` — devolve o id do endpoint cujo nome contém `wanted`, ou `nullopt` se não existir **ou se for o mesmo que o host está capturando para a sessão** (Review Focus 1).

- [ ] **Step 1: Testes:**
  - `MicSink.ChoosesByName`: endpoints `{a,"Alto-falantes (Realtek)"}`, `{b,"CABLE Input (VB-Audio Virtual Cable)"}`, wanted `"CABLE Input"` → `"b"`.
  - `MicSink.RefusesCaptureEndpoint`: mesmo caso com `capture_endpoint_id = "b"` → `nullopt`.
  - `MicSink.MissingIsNullopt`.
  - `MicService.DeliversToSink`: `service_t` com um `sink_t` falso numa porta livre, `begin(chave)`, 5 pacotes de `seal_packet` por UDP local → o falso recebe ≥ 5 blocos de 960 amostras; `end()` → `close()` chamado e porta liberada.
  - `MicService.IgnoresOtherKey`: pacotes de outra chave → só silêncio.
  - `Features.ListsMic`: `gabs::features()` contém `mic`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `mic_service.*` e `mic_sink_win.cpp` (thread com `syncThreadDesktop()` não é necessária: WASAPI não depende do desktop). No `stream.cpp`: `alloc` guarda uma cópia de `launch_session.gcm_key` num campo novo da sessão (`gabs_mic_key`), `start` chama `gabs::mic::instance().begin(session.gabs_mic_key)` (com duas sessões, vale a mais nova) e `end()` vai junto do `gabs::cursor::instance().restore()` em `join`, quando a última sessão termina. No `/serverinfo`: `<GabsFeatures>` com `gabs::features()`, ao lado de `GabsVersion`. Se o endpoint não existir: log `Gabs Remote: microfone virtual "<nome>" não encontrado; rode tools\setup\instalar-audio.ps1` uma vez por sessão e nada mais.
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Conferir com um emissor de teste:** um teste `DISABLED_MicService.LiveToCable` (rodado à mão com `--gtest_also_run_disabled_tests`) toca um tom de 440 Hz por 3 s no "CABLE Input"; o Gab olha a barra de nível do "CABLE Output" em `mmsys.cpl` → Gravação.
- [ ] **Step 6: Commit** — `feat(gabs): microfone do tablet no microfone virtual do PC`.

### Task 5: App — microfone

**Files:**
- Create: `android/app/src/main/jni/moonlight-core/gabsmic.c`, `android/app/src/main/java/com/limelight/gabs/mic/{OpusEncoderJni,MicPacket,MicSender,MicCapture,MicController}.java`, testes `android/app/src/test/java/com/limelight/gabs/mic/{MicPacketTest,MicControllerTest,MicSenderTest,MicCaptureConfigTest}.java`
- Modify: `android/app/src/main/jni/moonlight-core/Android.mk` (`gabsmic.c`), `AndroidManifest.xml` (`RECORD_AUDIO`), `Game.java` (criar, pausar no `onStop`, encerrar), `nvstream/http/ComputerDetails.java` + `NvHTTP.java` (`gabsFeatures`), `gabs/input/SessionMenu.java` (item do microfone), `res/xml/preferences.xml` + `values-pt-rBR/strings.xml` (preferência `gr_mic_on_connect`, desligada)

**Interfaces:**
- Consumes: formato do pacote e vetor de teste (Task 3), `GabsFeatures` com `mic` (Task 4).
- Produces:
  - `ComputerDetails.gabsFeatures` (`Set<String>`, vazio se o host não manda) — usado pelas Tasks 8, 11 e 12.
  - `final class MicPacket { static byte[] seal(int seq, byte[] opus, int opusLen, SecretKey rikey); }` — mesmo formato do host (AES/GCM/NoPadding do Java devolve cifra+tag; reordenar para tag+cifra).
  - `final class MicController { MicController(Capture capture, Sender sender, boolean onAtConnect); boolean isOn(); void toggle(); void onForeground(); void onBackground(); void onReconnect(SecretKey newKey); void close(); }` com `interface Capture { void start(); void stop(); }` e `interface Sender { void resetKey(SecretKey key); }`. Regras: começa ligado só se `onAtConnect`; `onBackground` para a captura sem mudar `isOn()`; `onForeground` volta se `isOn()`; `onReconnect` mantém `isOn()` e troca a chave.
  - `OpusEncoderJni`: `static native long create(int bitrate); static native int encode(long h, short[] pcm960, byte[] out); static native void destroy(long h);` em `gabsmic.c` (`OPUS_APPLICATION_VOIP`, `OPUS_SET_INBAND_FEC(1)`, `OPUS_SET_PACKET_LOSS_PERC(10)`).
  - `MicCapture`: `AudioRecord` com `MediaRecorder.AudioSource.VOICE_COMMUNICATION`, 48 kHz, mono, PCM 16, quadros de 960; `AcousticEchoCanceler`/`NoiseSuppressor` quando `isAvailable()`. A configuração sai de `static MicCapture.Config config()` (testável sem Android).
  - `MicSender`: `DatagramSocket` para `<endereço da sessão>:48002`; `seq` vive no `MicSender` da conexão e nunca volta a 0 com mudo/volta.

- [ ] **Step 1: Testes:**
  - `MicPacketTest.matchesHostVector`: `seal(7, "gabs", chave 00..0f)` = hex de `mic-packet.hex` (copiado no teste).
  - `MicControllerTest.startsMutedByDefault`, `startsOnWhenPreferred`, `toggleStartsAndStops`, `stopsInBackground` (captura parada, `isOn()` continua true), `resumesInForeground`, `keepsStateAcrossReconnect` (chave nova no sender, captura no mesmo estado).
  - `MicSenderTest.seqNeverRepeatsAcrossMute`: mandar 3, mudo, ligar, mandar 2 → `seq` 0..4.
  - `MicCaptureConfigTest.usesVoiceCommunication`: `config().source == VOICE_COMMUNICATION`, `sampleRate == 48000`, `frameSamples == 960`.
- [ ] **Step 2: Rodar e ver falhar** (`build-android.ps1 -Testes`).
- [ ] **Step 3: Implementar.** Permissão `RECORD_AUDIO` pedida na primeira vez que o Gab liga o microfone (negada → `Toast` "Sem permissão do microfone" e o item volta a "Ligar microfone"). Item do menu: "Ligar microfone" / "Silenciar microfone"; só aparece se `gabsFeatures` tiver `mic`. `Toast` ao ligar: "Microfone do tablet ligado no PC".
- [ ] **Step 4: Rodar** → PASS (todos os testes do app).
- [ ] **Step 5: Teste ao vivo em casa:** build de debug no tablet, host do build em console; ligar o microfone, falar e ver o nível do "CABLE Output" no PC; gravar 10 s no Gravador de Som do Windows e ouvir. Home → ponto verde some; voltar → microfone volta.
- [ ] **Step 6: Commit** (app, depois principal) — `feat(gabs): microfone do tablet no PC`.

### Task 6: Release 0.5.0 — som e microfone

**Files:**
- Modify: `versao.json` (`0.5.0`), `docs/notas/0.5.0.md`, `docs/testes/fase-5-checklist.md`

- [ ] **Step 1: Notas da 0.5.0** em pt-BR: microfone do tablet no PC (menu da sessão; começa mudo; o PC precisa do `instalar-audio.ps1` uma vez), caixas do PC em silêncio com "Tocar som no PC" desligado.
- [ ] **Step 2: Release** pelo passo a passo de `docs/release.md` (tag `v0.5.0`, CI, `preparar-release.ps1` com a senha digitada pelo Gab, `-Enviar`, publicar).
- [ ] **Step 3: Conferir com o Gab:** o app oferece a 0.5.0 ao abrir; o host pelo painel ("Procurar atualizações") e encerrando a sessão. Numa chamada real (Meet no Chrome do PC, escolhendo "CABLE Output" como microfone), o outro lado ouve o Gab sem eco com o som do PC tocando no tablet; repetir pelo Tailscale fora de casa se der.
- [ ] **Step 4: Checklist** `docs/testes/fase-5-checklist.md`, seções "Som do PC" e "Microfone" com ✓/✗ e evidência (atraso percebido, eco, qualidade). Commit e push — `docs: Release 0.5.0 (som e microfone)`.

### Task 7: Host — clipboard

**Files:**
- Create: `host/src/gabs/clipboard.h`, `host/src/gabs/clipboard.cpp`, `host/src/platform/windows/gabs/clipboard_win.cpp`, `host/tests/unit/gabs/test_clipboard.cpp`
- Modify: `host/src/nvhttp.cpp` (rotas `GET`/`POST /gabs/clipboard`), `host/src/main.cpp` (instalar o tracker com o observador da plataforma), `host/src/gabs/features.cpp` (ganha `clipboard`), cmake

**Interfaces:**
- Produces (namespace `gabs::clipboard`):
  - `struct content_t { enum class kind_e { empty, text, png } kind; std::string data; };` — `text` em UTF-8.
  - `constexpr std::size_t max_text = 1 << 20, max_png = 16 << 20;`
  - `class tracker_t` no molde do `gabs::cursor::tracker_t`: `tracker_t(platform_t platform, std::chrono::milliseconds poll_timeout = 10s); void on_pc_changed(); std::uint64_t write_from_app(content_t c); void poll(std::uint64_t known, reply_t reply); void tick(std::chrono::steady_clock::time_point now);` com `struct state_t { std::uint64_t version; content_t content; }`, `using reply_t = std::function<void(const state_t &, bool changed)>`.
  - `struct platform_t { std::function<content_t()> read; std::function<bool(const content_t &)> write; };` — o Windows lê `CF_UNICODETEXT` ou `CF_DIBV5`/`CF_DIB` (→ PNG pelo WIC) e escreve `CF_UNICODETEXT` ou `CF_DIB` + o formato registrado `"PNG"`; `OpenClipboard` com até 10 tentativas de 20 ms; janela só de mensagens com `AddClipboardFormatListener` numa thread que chama `on_pc_changed()`.
  - Regras: `write_from_app` grava no PC e guarda o SHA-256 do que gravou; um `on_pc_changed` cujo conteúdo tem esse hash não aumenta a versão. Conteúdo acima do limite vira `empty` (a rota responde `204`).

- [ ] **Step 1: Testes** (com `platform_t` falso):
  - `ClipboardTracker.PcChangeBumpsVersionAndWakesPoll`.
  - `ClipboardTracker.IgnoresOwnWrite`: `write_from_app("oi")` → o observador dispara com "oi" → a versão não muda e o poll não acorda.
  - `ClipboardTracker.OversizeIsEmpty`: texto de 1 MiB + 1 e PNG de 16 MiB + 1 → `empty`.
  - `ClipboardTracker.PollTimesOutWithSameVersion` (via `tick`).
  - `ClipboardTracker.OldVersionAnswersAtOnce`.
  - `ClipboardHttp.RejectsOtherTypeAndSize`: função pura `parse_post(content_type, body)` → `415`/`413`/ok.
- [ ] **Step 2: Rodar e ver falhar** (`--gtest_filter=Clipboard*`).
- [ ] **Step 3: Implementar** o tracker, a plataforma Windows e as rotas (formato em "Formatos"; `409` sem sessão; o long poll responde de outra thread como o `/gabs/cursor`).
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Conferir à mão** com `curl` usando o certificado de um cliente pareado (como no teste do `/gabs/cursor` da 0.4.1): copiar texto no PC → o `GET` acorda; `POST` de um PNG → colar no Paint.
- [ ] **Step 6: Commit** — `feat(gabs): clipboard do PC pelo /gabs/clipboard`.

### Task 8: App — clipboard

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/clipboard/{ClipboardSync,ClipboardPoller,AndroidClipboard}.java`, testes `ClipboardSyncTest.java`, `ClipboardPollerTest.java`
- Modify: `NvHTTP.java` (`gabsClipboardGet(long known)`, `gabsClipboardPost(String mime, byte[] body)`), `Game.java` (início, foco e fim), `SessionMenu.java` (itens manuais), `AndroidManifest.xml` + `res/xml/file_paths.xml` (FileProvider para a imagem colada), `preferences.xml` + strings (`gr_clipboard_auto`, ligada)

**Interfaces:**
- Consumes: rotas da Task 7; `ComputerDetails.gabsFeatures` com `clipboard` (Task 5).
- Produces:
  - `final class ClipboardSync { ClipboardSync(Local local, Remote remote, boolean auto, Notifier notifier); void onLocalChanged(); void onFocusGained(); void onRemote(long version, String mime, byte[] data); void pushNow(); void pullNow(); }` com `interface Local { Clip read(); void write(Clip c); }`, `interface Remote { long post(Clip c) throws IOException; }`, `interface Notifier { void tooBig(); void failed(); }` e `final class Clip { String mime; byte[] data; }`.
  - Regras: guarda o SHA-256 do último conteúdo que veio do PC e do último que mandou; não manda de volta o que acabou de receber nem repete o que já mandou; acima do limite chama `tooBig()` uma vez por conteúdo; com `auto` desligado, só `pushNow`/`pullNow` fazem algo. O Android só deixa ler o clipboard com a janela em foco: `onFocusGained` lê e manda se mudou (o caso "copiei em outro app e voltei").
  - `ClipboardPoller` no molde do `CursorShapePoller` (404 = host sem a rota, para; `304` = nada; `204` = nada a colar).

- [ ] **Step 1: Testes:** `ClipboardSyncTest.pushesLocalChange`, `noEcho` (remoto "oi" escrito no local → `onLocalChanged` não faz `post`), `noRepeat`, `oversizeWarnsOnce`, `manualModeOnlyOnButtons`, `focusGainedPushesChange`, `imageRoundTripKeepsMime`; `ClipboardPollerTest.stopsOn404`, `ignores304And204`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.** Imagem do PC → arquivo em `cacheDir/clipboard/` exposto pelo FileProvider como `ClipData` de URI; imagem do tablet → lida pelo `ContentResolver`, convertida para PNG se vier em outro formato. Itens do menu "Mandar clipboard ao PC" e "Trazer clipboard do PC" só com o automático desligado e `clipboard` no host. Mensagem do `tooBig`: "Clipboard grande demais; use Enviar arquivo".
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Ao vivo:** texto e imagem nos dois sentidos (print do PC com Win+Shift+S → colar no Samsung Notes; foto da galeria copiada → colar no Paint); texto copiado em outro app do tablet e volta à sessão → cola no PC.
- [ ] **Step 6: Commit** (app, depois principal) — `feat(gabs): clipboard entre o tablet e o PC`.

### Task 9: Release 0.5.1 — clipboard

- [ ] **Step 1:** `versao.json` `0.5.1`, `docs/notas/0.5.1.md` (clipboard automático, limites, como desligar).
- [ ] **Step 2: Release** por `docs/release.md`; app e host atualizados (painel + encerrar sessão).
- [ ] **Step 3:** seção "Clipboard" do checklist com ✓/✗ (texto, imagem, laço, grande demais, modo manual). Commit e push — `docs: Release 0.5.1 (clipboard)`.

### Task 10: Host — arquivos

**Files:**
- Create: `host/src/gabs/files.h`, `host/src/gabs/files.cpp`, `host/src/platform/windows/gabs/files_win.cpp`, `host/tools/gabs-enviar.cpp`, `host/tests/unit/gabs/test_files.cpp`
- Modify: `host/src/nvhttp.cpp` (rotas de `/gabs/files`), `host/src/platform/windows/misc.h` (declarar `retrieve_users_token` e `impersonate_current_user`, `// Gabs Remote:`), `host/tools/CMakeLists.txt` (`gabs-enviar` com `WIN32`, sem janela de console), `host/src/gabs/features.cpp` (ganha `files`), `installer/gabs-remote.nsi` (copiar `gabs-enviar.exe`; atalho `$SENDTO\Gabs Remote (tablet).lnk` só na instalação manual, como o SudoVDA), cmake

**Interfaces:**
- Produces (namespace `gabs::files`):
  - `std::optional<std::string> safe_name(std::string_view requested);` — tira caminho (`/`, `\`), troca `<>:"|?*` e controles por `_`, tira pontos e espaços do fim, prefixa `_` em nomes reservados (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`, com ou sem extensão), corta em 200 bytes UTF-8 sem partir caractere; vazio ou `.`/`..` → `nullopt`.
  - `std::filesystem::path unique_path(const std::filesystem::path &dir, const std::string &name);` — `nome.ext`, `nome (2).ext`, `nome (3).ext`...
  - `using write_fn_t = std::function<std::error_code(const std::filesystem::path &part, std::uint64_t offset, std::string_view chunk)>;` e `class upload_store_t { public: explicit upload_store_t(std::filesystem::path dir, write_fn_t write = default_write); result_t put(std::string_view id, std::string_view name, std::uint64_t size, std::uint64_t offset, std::string_view chunk); std::uint64_t received(std::string_view id) const; void cleanup(std::chrono::system_clock::time_point now); };` com `struct result_t { int status; std::uint64_t received; std::string final_name; }` (`200`, `409`, `400`, `507` conforme "Formatos"). `id` só `[0-9a-f]{32}`.
  - `struct outgoing_t { std::string id; std::filesystem::path path; std::uint64_t size; };` e `std::vector<outgoing_t> read_queue(const std::filesystem::path &queue_dir);` — lê os `.txt` da fila; `id` = SHA-256 (32 primeiros hex) de `<nome do .txt>|<caminho>`; ignora pastas e o que não existe.
  - Windows (`files_win.cpp`): `std::optional<std::filesystem::path> user_folder(KNOWNFOLDERID)` do usuário do console (Downloads e LocalAppData) e as leituras e gravações feitas dentro de `impersonate_current_user`.

- [ ] **Step 1: Testes:**
  - `FileNames.StripsPath` (`..\..\Windows\x.dll` → `x.dll`), `ReplacesForbidden` (`a:b?.png` → `a_b_.png`), `ReservedNames` (`CON.txt` → `_CON.txt`), `TrimsTrailingDotsAndSpaces`, `KeepsUnicode` (`relatório 😀.pdf` igual), `CutsLongNameOnCharBoundary`, `EmptyAndDotsAreRejected`.
  - `FileNames.UniquePath`: com `a.txt` e `a (2).txt` existindo → `a (3).txt`.
  - `UploadStore.ChunksCompleteAndRename`: 3 pedaços → `done` com o nome final e o conteúdo certo; `.parcial` vazio.
  - `UploadStore.WrongOffsetIs409WithReceived`, `ResumesAfterRestart` (novo `upload_store_t` na mesma pasta → `received` certo), `RejectsBadIdNameAndSize` (id fora do padrão, size 0, size > 64 GiB, chunk passando do size), `CleanupRemovesOldParts`.
  - `UploadStore.DiskFullIs507AndRemovesPart`: `upload_store_t` com um `write_fn_t` que devolve `std::errc::no_space_on_device` → `507` e o `.part` apagado.
  - `OutQueue.ReadsLinesSkipsFoldersAndMissing`, `OutQueue.IdIsStable`.
- [ ] **Step 2: Rodar e ver falhar** (`--gtest_filter=FileNames.*:UploadStore.*:OutQueue.*`).
- [ ] **Step 3: Implementar** `files.*`, `files_win.cpp`, as rotas (o `GET /gabs/files/out/<id>` escreve em pedaços de 1 MiB com o envio assíncrono do Simple-Web-Server, respeitando `Range`) e o `gabs-enviar.exe` (grava a fila em `%LOCALAPPDATA%\Gabs Remote\enviar\`; dando certo, não mostra nada; dando erro, `MessageBoxW` com o motivo em pt-BR). A fila do usuário é lida impersonando-o; o arquivo é aberto impersonado — se o usuário não pode ler, sai da lista.
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Conferir à mão:** `curl` com o certificado de cliente mandando 3 pedaços → arquivo em `Downloads\Gabs Remote` com o dono e as permissões herdadas da pasta do Gab (`icacls`); `gabs-enviar.exe C:\Windows\System32\config\SAM` → não aparece na lista (o usuário não lê esse arquivo).
- [ ] **Step 6: Commit** — `feat(gabs): arquivos entre o tablet e o PC (host)`.

### Task 11: App — arquivos

**Files:**
- Create: `android/app/src/main/java/com/limelight/gabs/files/{ShareToPcActivity,FileTransferService,UploadTask,DownloadTask,OutboxPoller,TransferNotifier}.java`, testes `UploadTaskTest.java`, `DownloadTaskTest.java`, `OutboxPollerTest.java`
- Modify: `AndroidManifest.xml` (atividade com `ACTION_SEND`/`ACTION_SEND_MULTIPLE` `*/*`, rótulo "Enviar para o PC"; serviço `dataSync`; permissões de serviço em primeiro plano e notificação), `NvHTTP.java` (chamadas de `/gabs/files`), `Game.java` (liga o `OutboxPoller` durante a sessão), strings

**Interfaces:**
- Consumes: rotas da Task 10; `gabsFeatures` com `files`.
- Produces:
  - `final class UploadTask { UploadTask(Source src, Remote remote, Progress progress); void run() throws IOException; }` com `interface Source { String name(); long size(); InputStream openAt(long offset) throws IOException; }`, `interface Remote { long received(String id) throws IOException; Reply put(String id, String name, long size, long offset, byte[] chunk, int len) throws IOException; }` e `final class Reply { int status; long received; String finalName; }`. Pedaços de 8 MiB; `409` → recomeça do `received` do host; falha de rede → espera 2, 4, 8... até 60 s e continua do `received`; `507` → para com erro "Sem espaço no PC".
  - `final class DownloadTask { DownloadTask(Remote remote, Sink sink, Progress progress); void run(OutItem item) throws IOException; }` com `interface Remote { InputStream get(String id, long from) throws IOException; void delete(String id) throws IOException; }`, `interface Sink { long written(); OutputStream append() throws IOException; void finish() throws IOException; }` e `final class OutItem { String id; long size; String name; }`. O `Sink` sabe o tamanho já gravado (MediaStore `Download/Gabs Remote`, `IS_PENDING = 1`, abrindo em `"wa"`) e o `GET` pede `Range` daí; ao terminar `IS_PENDING = 0` e `DELETE` na fila.
  - `OutboxPoller`: a cada 3 s durante a sessão, `GET /gabs/files/out`; item novo → `FileTransferService`.
  - `ShareToPcActivity`: sem tela própria; escolhe o PC pareado (se houver mais de um, `AlertDialog` com a lista), entrega as URIs ao `FileTransferService` e fecha. PC desligado/inalcançável → notificação "PC fora do ar; tente de novo" (sem WoL automático nesta fase).
  - Notificação por arquivo com progresso (`%` e MB), "Enviado para o PC: <nome>" / "Recebido do PC: <nome>" (toque abre o arquivo).

- [ ] **Step 1: Testes:** `UploadTaskTest.sendsInChunks`, `resumesFromHostOffset` (host já tem 8 MiB → primeiro `put` com offset 8 MiB), `recoversFrom409`, `retriesOnNetworkErrorThenContinues`, `stopsOn507`; `DownloadTaskTest.resumesWithRange`, `deletesFromQueueWhenDone`; `OutboxPollerTest.startsEachItemOnce`, `stopsOn404`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → PASS.
- [ ] **Step 5: Ao vivo:** compartilhar 3 fotos e um vídeo de 1 GB da galeria para "Enviar para o PC" (sem sessão aberta); desligar o Wi-Fi do tablet no meio do vídeo e religar → continua e termina; no PC, "Enviar para → Gabs Remote (tablet)" com um PDF e um zip → chegam em `Download/Gabs Remote` com a sessão aberta.
- [ ] **Step 6: Commit** (app, depois principal) — `feat(gabs): enviar arquivos para o PC e receber do PC`.

### Task 12: Ações remotas

**Files:**
- Create: `host/src/gabs/actions.h`, `host/src/gabs/actions.cpp`, `host/src/platform/windows/gabs/actions_win.cpp`, `host/tests/unit/gabs/test_actions.cpp`, `android/app/src/main/java/com/limelight/gabs/session/PcActions.java`, `android/app/src/test/java/com/limelight/gabs/session/PcActionsTest.java`
- Modify: `host/src/nvhttp.cpp` (`POST /gabs/action`), `host/src/gabs/features.cpp` (ganha `actions`), cmake; `NvHTTP.java` (`gabsAction(String)`), `SessionMenu.java` (submenu "PC"), strings

**Interfaces:**
- Produces:
  - Host: `enum class gabs::actions::action_e { lock, sleep, restart, shutdown };`, `std::optional<action_e> parse(std::string_view)`, `void run_later(action_e, std::chrono::milliseconds delay = 1s)`. Windows: `lock` = `rundll32.exe user32.dll,LockWorkStation` lançado como o usuário (`platf::run_command(false, true, ...)`); `sleep` = `SetSuspendState(FALSE, FALSE, FALSE)`; `restart`/`shutdown` = `InitiateShutdownW(nullptr, L"Gabs Remote", 0, SHUTDOWN_RESTART ou SHUTDOWN_POWEROFF | SHUTDOWN_FORCE_OTHERS, SHTDN_REASON_FLAG_PLANNED)` sem `SHUTDOWN_HYBRID` (desligar completo, o WoL funciona). Log `Gabs Remote: ação <nome> pedida pelo tablet`.
  - App: `final class PcActions { enum Kind { LOCK, SLEEP, RESTART, SHUTDOWN } static boolean needsConfirm(Kind k); static boolean endsSession(Kind k); static String param(Kind k); }` — confirmação e fim de sessão para `SLEEP`, `RESTART`, `SHUTDOWN`; `LOCK` não.

- [ ] **Step 1: Testes:** `Actions.ParsesKnownAndRejectsOthers` (`lock`…`shutdown` ok; `""`, `reboot`, `LOCK` → `nullopt`); `PcActionsTest.confirmAndEndSession`, `paramNames`.
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.** No app: submenu "PC" com "Bloquear", "Suspender", "Reiniciar", "Desligar"; confirmação "Suspender o PC? A sessão termina." (e equivalentes); depois de `202`, as três últimas encerram a sessão como o "Desconectar" (`/cancel` antes da ação, para o host desfazer a tela virtual).
- [ ] **Step 4: Rodar** → PASS (host e app).
- [ ] **Step 5: Ao vivo:** bloquear (a tela de bloqueio aparece na sessão; desbloquear pelo tablet); suspender e acordar pelo WoL do app; reiniciar e o host volta sozinho (serviço); desligar e ligar pelo WoL.
- [ ] **Step 6: Commit** (host, app, principal) — `feat(gabs): bloquear, suspender, reiniciar e desligar o PC pelo tablet`.

### Task 13: Release 0.5.2, checklist e fechamento da fase 5

**Files:**
- Modify: `versao.json` (`0.5.2`), `docs/notas/0.5.2.md`, `docs/testes/fase-5-checklist.md`, `CLAUDE.md` ("Onde fica cada coisa": `gabs/mic`, `gabs/clipboard`, `gabs/files`, `gabs/actions`, `gabs-enviar`, `instalar-audio.ps1`, rotas novas e `GabsFeatures`), spec §10 (fase 5 feita), `docs/sessoes.md`

- [ ] **Step 1: Notas da 0.5.2** (enviar arquivos nos dois sentidos, ações do PC) e **Release** por `docs/release.md`; o instalador novo cria o atalho "Enviar para" só na instalação manual — se o host vier por atualização silenciosa, o Gab roda o `GabsRemote-Setup-0.5.2.exe` à mão uma vez (anotar nas notas).
- [ ] **Step 2: Critério 5 (sem câmera) com o Gab**, de preferência fora de casa pelo Tailscale: som do PC no tablet com as caixas mudas; chamada real com o microfone do tablet (Meet e Discord); clipboard texto e imagem nos dois sentidos; arquivo grande nos dois sentidos com uma queda de rede no meio; as quatro ações.
- [ ] **Step 3: Fechar `docs/testes/fase-5-checklist.md`** com ✓/✗ e evidência por item e pelos 5 itens da Review Focus.
- [ ] **Step 4: Atualizar** `CLAUDE.md`, spec §10, `docs/sessoes.md` (fase 5 feita, estado ao fechar, prompt do plano da fase 6) e o grafo (`/graphify . --update`).
- [ ] **Step 5: Commit e push** — `docs: Release 0.5.2 e fechamento da fase 5`.

---

## Fora deste plano
- Câmera do tablet como webcam (fase 6).
- Microfone com nome "Microfone Gabs Remote" no Windows: o VB-CABLE aparece como "CABLE Output"; renomear o endpoint exige mexer no registro protegido do serviço de áudio. Driver próprio só se for inevitável (spec §11).
- Microfone do PC para o tablet, áudio em mais de 2 canais, escolher o microfone do tablet (interno ou fone Bluetooth: fica o padrão do Android).
- Clipboard de arquivos (copiar arquivo no Explorer e colar no tablet) e de HTML/RTF: usar "Enviar para".
- Enviar pastas, WoL automático ao compartilhar com o PC desligado, histórico de transferências.
- Testes adiados das fases 3 e 4 (`docs/sessoes.md`, "Testes adiados"): continuam valendo e podem rodar junto da Task 13 se o Gab quiser.

## Próxima sessão

Para **executar este plano**, comece uma sessão nova e use:

> Gabs Remote — executar o plano `docs/superpowers/plans/2026-11-11-fase-5-audio-mic-clipboard-arquivos.md`. Leia o `CLAUDE.md`, o plano, as decisões em `docs/decisoes/` e `docs/release.md`. Execução nativa (executing-plans), fazendo commit, push, tag e Release sem pedir (só peça meu ok se algo afetar outro projeto meu); eu digito a senha da chave do manifesto e rodo como administrador o que instala driver ou mexe no serviço. A Task 1 precisa de mim para instalar o VB-CABLE. As Tasks 6, 9 e 13 são Releases com teste ao vivo comigo; se eu não estiver por perto, publique e deixe a conferência anotada no checklist. Ao parar, atualize `docs/sessoes.md` e me dê o prompt da próxima sessão.

Se a execução parar no meio:

> Gabs Remote — continuar a execução de `docs/superpowers/plans/2026-11-11-fase-5-audio-mic-clipboard-arquivos.md`. Leia o `CLAUDE.md`, confira no `git log` (principal e submódulos), nos checkboxes e no ledger `.superpowers/sdd/` o que já foi feito e siga da próxima tarefa.
