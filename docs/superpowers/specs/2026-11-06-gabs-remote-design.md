# Gabs Remote — Design (spec)

- **Data:** 06/11/2026
- **Status:** aprovado em conversa; aguardando revisão do Gab deste documento
- **Dono:** Gab (`gabavares` no GitHub)

## 1. Objetivo

Um sistema próprio de acesso remoto para o Gab trabalhar no PC de casa pelo **Galaxy Tab S10+**, com latência menor, imagem melhor e mais recursos que o Acesso Remoto do Google (e que o Parsec/SuperDisplay que ele já usa).

Saídas:
- **Instalador Windows** (`GabsRemote-Setup-x.y.z.exe`) que instala o host como serviço e inicia com o PC.
- **APK Android** (`GabsRemote-x.y.z.apk`) para o tablet; o celular usa o mesmo APK sem ajustes específicos por enquanto.
- Ambos com **atualização automática** pelas Releases do GitHub.

### 1.1 Critérios de sucesso
1. **Latência:** na rede de casa (Wi-Fi 5 GHz), clique-até-imagem ≤ 30 ms em média a 120 fps; fora de casa, utilizável para trabalho com 50 Mbps ou mais. Medido pelo medidor de latência do projeto (§9.3), comparado lado a lado com o Acesso Remoto do Google.
2. **Imagem:** texto nítido em IDE e Figma sem borrão em movimento; 60/90/120 fps escolhíveis.
3. **Resolução:** o tablet recebe uma tela na resolução dele (2800×1752 ou escala), sem barras pretas, e existem perfis fixos (1440p, 1080p, 720p).
4. **Entrada:** S Pen com pressão, inclinação, hover e botão funcionando no Photoshop, Illustrator e Figma; toque direto e modo trackpad; teclado físico com todos os atalhos (Ctrl, Alt, Win, Alt+Tab, F1–F12).
5. **Mídia:** áudio do PC no tablet; microfone do tablet como microfone do PC; câmera do tablet como webcam do PC (em apps DirectShow: Chrome, Discord, Zoom, OBS, Meet).
6. **Disponibilidade:** o PC sobe o host sozinho ao ligar (inclusive na tela de login e no UAC); o app liga o PC por WoL; reconecta sozinho após queda de rede.
7. **Atualização:** publicar uma Release no GitHub faz o host e o app oferecerem a nova versão, com as notas, sem reinstalar à mão.

### 1.2 Fora do escopo agora
- Clientes iOS, macOS, Linux; acesso a outros PCs além do PC do Gab (o desenho não impede, mas não é objetivo).
- Uso por terceiros, contas, multiusuário.
- Webcam visível no app Câmera do Windows / Teams novo (exige Windows 11, ver §6.4).

## 2. Contexto e restrições levantados

| Item | Valor |
|---|---|
| PC | Windows 10 Pro 22H2 (19045), Ryzen 7 5800XT, **RTX 5060 Ti** (NVENC com AV1/HEVC/H.264), monitor 2560×1440 @ 180 Hz, Ethernet 1 Gbps |
| Drivers já instalados | Parsec Virtual Display Adapter, SuperDisplay Virtual Adapter |
| Tablet | Galaxy Tab S10+ — 2800×1752 @ 120 Hz, decodificação AV1/HEVC por hardware, S Pen (pressão, inclinação, hover, botão) |
| Rede | Vivo Fibra, roteador Askey RTF3505VW-N1 (CGNAT possível; IPv6 provável) |
| WoL | Já funciona hoje (Alexa); o mecanismo é genérico e independe do modelo do roteador |
| Hospedagem | Hostinger Premium compartilhada, servidor no Brasil (verificado em `docs/resposta servidor.md`): PHP e um processo Node mantido por vigia, **nenhuma porta de entrada (TCP/UDP) alcançável**, sem root/Docker, IPv4 compartilhado, `wss://` improvável. DNS na Hostinger com subdomínios livres. **Não serve para sinalização WebSocket nem TURN**; para isso seria preciso uma VPS (ex.: Hostinger KVM 1) |
| GitHub | conta `gabavares`, commits com `43415454+gabavares@users.noreply.github.com` |
| Ferramentas no PC hoje | Git, Node, Python, .NET. Faltam Visual Studio Build Tools/MSYS2 (para o Sunshine), Android Studio + SDK/NDK, JDK |

## 3. Abordagem escolhida

**Fork do Sunshine (host) + fork do moonlight-android (app)**, trazendo de outros forks GPL o que já existe, e adicionando os módulos que faltam.

Motivo: latência baixa de verdade é a parte mais difícil e o Sunshine/Moonlight já resolve isso (captura por GPU, NVENC, transporte UDP com FEC, decodificação de baixa latência, tela virtual, caneta e toque). Construir do zero levaria meses só para empatar.

### 3.1 Bases
| Base | Por quê | Traz de outros forks |
|---|---|---|
| **LizardByte/Sunshine** (upstream) | O mais ativo; releases em 2026; `libvirtualhid` (teclado, mouse, toque, caneta, gamepad) desde v2026.816; builds assinados via SignPath | **Apollo** (ClassicOldSong): tela virtual por cliente com a resolução do cliente, clipboard sync. **Foundation/AlkaidLab Sunshine**: protocolo de microfone do cliente |
| **moonlight-stream/moonlight-android** (upstream) | Cliente de referência, decodificação de baixa latência madura | **Artemis** (fork Android do Apollo): lado cliente da tela virtual e do clipboard |

A primeira tarefa da fase 1 reconfirma a escolha conferindo atividade e licença dos repositórios (commits recentes, releases, issues). Se o upstream do Sunshine já tiver absorvido tela virtual ou microfone, usamos o upstream.

**Licença:** GPL-3.0 herdada. Os repositórios de código ficam públicos no GitHub do Gab (como o vagabs). Nada sigiloso entra nos repositórios.

## 4. Arquitetura

```
 Galaxy Tab S10+ (app Gabs Remote)                       PC Windows (host Gabs Remote)
 ┌──────────────────────────────┐                ┌──────────────────────────────────────┐
 │ UI: lista de PCs, ligar (WoL)│                │ Serviço "GabsRemote" (SYSTEM, auto)  │
 │ Decoder MediaCodec (AV1/HEVC)│◄── vídeo UDP ──│  Captura DXGI/WGC → NVENC            │
 │ Áudio (Opus)                 │◄── áudio UDP ──│  Áudio WASAPI loopback → Opus        │
 │ Entrada: toque, S Pen, teclado──► controle ──►│  Entrada → libvirtualhid             │
 │ Mic (Opus) ──────────────────┼──► mic ──────►│  → driver de microfone virtual       │
 │ Câmera (H.264) ──────────────┼──► câmera ───►│  → webcam virtual DirectShow         │
 │ Clipboard / arquivos ◄───────┼── canal dados►│  Clipboard / arquivos                │
 │ Updater (GitHub Releases)    │                │  Tela virtual (IddCx) por perfil     │
 └──────────────────────────────┘                │  Bandeja + painel web local          │
                                                 │  Updater (GitHub Releases)           │
                                                 └──────────────────────────────────────┘
```

### 4.1 Componentes

| # | Componente | Linguagem | Faz | Depende de |
|---|---|---|---|---|
| H1 | **Host core** (fork Sunshine) | C++ | Captura, encoder, transporte, pareamento, entrada, áudio do sistema, tela virtual | NVENC, libvirtualhid, driver de tela virtual |
| H2 | **Tela virtual** | driver IddCx (SudoVDA do Apollo ou Virtual-Display-Driver) | Cria um monitor com a resolução/Hz pedidos pelo cliente; remove ao desconectar | — |
| H3 | **Microfone virtual** | driver de áudio (Virtual-Audio-Driver da VirtualDrivers, assinado) | Expõe "Microfone Gabs Remote" no Windows; o host escreve nele o áudio vindo do tablet | — |
| H4 | **Webcam virtual** | DirectShow (base softcam/OBS) | Expõe "Câmera Gabs Remote"; o host entrega os quadros decodificados vindos do tablet | — |
| H5 | **Canal de dados** | C++ dentro do host | Clipboard (texto + imagem), transferência de arquivos, comandos (bloquear, suspender, reiniciar, desligar), perfis por app | H1 |
| H6 | **Bandeja + painel** | painel web do Sunshine, rebatizado | Status, clientes pareados, perfis, logs de acesso, botão "Procurar atualizações" | H1 |
| H7 | **Updater do host** | pequeno executável à parte (C# .NET ou C++) | Confere a Release, mostra notas, baixa, verifica, instala em silêncio e reinicia o serviço | GitHub Releases |
| A1 | **App core** (fork moonlight-android) | Java/Kotlin + C (NDK) | Conexão, decodificação, áudio, entrada básica | — |
| A2 | **Entrada avançada** | Kotlin | S Pen completa, modos de toque, gestos, teclado virtual com teclas especiais, barra de atalhos, teclado físico | A1 |
| A3 | **Uplink de mídia** | Kotlin | Captura mic (Opus) e câmera (Camera2 → H.264 por MediaCodec) e envia | A1 |
| A4 | **WoL + descoberta** | Kotlin | mDNS na LAN, pacote mágico, estado "PC ligado/desligado" | — |
| A5 | **Updater do app** | Kotlin | Confere a Release, baixa o APK, verifica e instala com PackageInstaller | GitHub Releases |
| N1 | **Conectividade remota** | ver §5 | Acesso de fora de casa | depende do resultado do prompt do servidor |
| W1 | **Cliente web** (fase 8) | TS + gateway WebRTC no host | Acesso pelo navegador reaproveitando o encoder | H1 |

Cada componente novo vive em pasta própria e conversa com o core por uma interface pequena (fila de quadros, fila de amostras de áudio, mensagens do canal de dados), para poder ser testado sozinho.

## 5. Rede e conexão

### 5.1 Em casa (LAN)
- O host se anuncia por mDNS; o app lista o PC sozinho.
- Conexão direta UDP (protocolo do Sunshine/Moonlight, com FEC e criptografia).
- Wi-Fi 5 GHz recomendado; o app avisa se o tablet estiver em 2,4 GHz.

### 5.2 Fora de casa
A hospedagem compartilhada da Hostinger **não aceita UDP nem portas próprias**, então ela não pode ser relay. Ordem de preferência:

1. **IPv6 direto**, se a Vivo entregar IPv6 ao PC e ao 4G/5G do tablet: sem NAT, latência mínima. O host abre só as portas do serviço no firewall do Windows.
2. **Port forward IPv4** no roteador Vivo, se a linha não estiver em CGNAT, com o endereço publicado em um subdomínio do Gab (ex.: `remote.<domínio>`), atualizado pelo host por uma API simples (PHP na Hostinger) ou pela API do DNS.
3. **Tailscale como caminho padrão de fallback** (app oficial do Tailscale no PC e no tablet; embutir via `libtailscale` fica como melhoria futura): P2P com hole-punching e relay DERP quando não der; o app detecta o endereço Tailscale do PC. Funciona com CGNAT e não depende de servidor do Gab.
4. **Relay próprio** (TURN/UDP) só se um dia houver VPS; o desenho do cliente aceita um endereço de relay configurável.

O app testa os caminhos em paralelo e usa o primeiro que responder com menor RTT (estilo ICE), e mostra qual está em uso.

**Papel da hospedagem do Gab:** página de "onde está o PC" (endereço atual, estado), registro de ligar o PC (fila de WoL), e no futuro hospedar o cliente web. Tudo por HTTPS, sem processos persistentes.

### 5.3 Wake-on-LAN
- **Em casa:** o app envia o pacote mágico por broadcast (UDP 9) com o MAC do PC, que o host registra no pareamento.
- **Fora de casa:** o app chama o mesmo mecanismo que já funciona hoje com a Alexa (genérico, independente de modelo de roteador). Como alternativa: pacote mágico pela internet via port forward para o broadcast, ou pelo Tailscale para outro aparelho da rede.
- Depois de enviar, o app mostra "Ligando…" e conecta sozinho quando o host responder.
- O host confere no primeiro uso se o WoL está ativo na placa (Realtek PCIe GbE) e se o "Início rápido" do Windows atrapalha, e orienta o ajuste.

### 5.4 Segurança
- Pareamento por PIN e certificados (Sunshine), e **2º fator opcional para conexões de fora de casa** (código no app + confirmação na bandeja do PC, configurável).
- Notificação no PC quando alguém conecta; log de acessos no painel.
- Painel web só em localhost por padrão.
- Bloquear o PC automaticamente ao desconectar (opcional, ligado por padrão para conexões externas).

## 6. Mídia e entrada

### 6.1 Vídeo e resolução
- **Perfis:**
  - *Nativo do tablet:* tela virtual em 2800×1752 (ou escala 2/3, 1/2), 60/90/120 Hz.
  - *Espelhar monitor:* 2560×1440 reduzido ou recortado.
  - *Fixos:* 1080p, 720p.
  - *Segundo monitor:* tela virtual estendida, com o monitor físico continuando ativo (substitui o SuperDisplay).
- Codec: AV1 → HEVC → H.264, negociado. Bitrate automático com limite manual. **Modo texto 4:4:4** se o decodificador do Tab S10+ suportar (a conferir na fase 2); senão, HEVC 4:2:0 com bitrate alto.
- HDR opcional (desligado por padrão).
- Overlay de estatísticas (latência, fps, bitrate, perda, caminho de rede).
- Opção de apagar o monitor físico durante a sessão (privacidade).

### 6.2 Entrada
- **S Pen:** pressão, inclinação, hover e botão lateral, entregues como caneta do Windows (pointer injection / libvirtualhid). Rejeição de palma enquanto a caneta está perto.
- **Modos de toque:** toque direto (como tela touch), trackpad (cursor relativo, como no Google), só caneta (toques viram gestos). Os modos alternam pela barra.
- **Gestos:** pinça para zoom local (só no tablet), dois dedos para rolar, toque com dois dedos para clique direito, três dedos para mostrar a barra.
- **Teclado:** físico do Book Cover ou Bluetooth com todos os atalhos capturados (inclusive Alt+Tab e Win); teclado virtual com fileira de Ctrl, Alt, Win, Esc, Tab, F1–F12 e setas.
- **Barra de atalhos personalizável** e **perfis por app:** quando o Photoshop ganha foco no PC, o host avisa e o app troca a barra e o modo (ex.: caneta + Ctrl+Z, B, E, zoom).
- **Modo mesa digitalizadora:** o tablet mostra a tela, mas o toque é ignorado e só a caneta mapeia para o monitor escolhido.
- Gamepad (já vem do Moonlight).

### 6.3 Áudio e microfone
- Áudio do PC: WASAPI loopback → Opus → tablet (vem do Sunshine). Opção de silenciar as caixas do PC durante a sessão.
- Microfone: tablet captura (16/48 kHz, Opus, baixa latência) → host → driver de microfone virtual. O app tem botão de mudo e indicador.

### 6.4 Câmera como webcam
- Tablet: Camera2 (frontal ou traseira, 720p/1080p, 30 fps) → H.264 no MediaCodec → host.
- Host: decodifica (NVDEC) → entrega para a **webcam virtual DirectShow** "Câmera Gabs Remote".
- **Limite conhecido:** no Windows 10 a câmera aparece em Chrome, Edge, Discord, Zoom, OBS e Meet, mas **não** no app Câmera do Windows nem no Teams novo. No Windows 11, acrescentar o caminho `MFCreateVirtualCamera` para cobertura total.

### 6.5 Clipboard e arquivos
- Clipboard em dois sentidos, texto e imagem, automático ou manual (botão), com limite de tamanho.
- Arquivos: "Enviar para o tablet" (menu de contexto no PC) e "Enviar para o PC" (compartilhar no Android → pasta `Downloads\Gabs Remote`), com progresso e retomada.

## 7. Disponibilidade e robustez
- Host como **serviço do Windows** (SYSTEM, início automático, recuperação automática se cair) com um processo de sessão para captura e entrada, como o Sunshine já faz. Funciona na tela de login e no UAC.
- O app reconecta sozinho após queda de rede (troca de Wi-Fi para 4G) e mantém a sessão no host por um tempo configurável.
- Watchdog: se o encoder ou a captura falhar, o host reinicia o pipeline sem derrubar a sessão; tudo vai para log com rotação.
- Tela virtual removida ao fim da sessão; resolução original do monitor restaurada mesmo se o host cair (restauração na próxima subida).

## 8. Atualização automática

Padrão igual ao do vagabs: Releases do GitHub, notas em pt-BR, ok do Gab para publicar cada versão.

- **Repositórios:**
  - `gabavares/gabs-remote`: repositório principal com docs, scripts, relay, CI, Releases e os forks como submódulos.
  - `gabavares/gabs-remote-host`: fork do Sunshine.
  - `gabavares/gabs-remote-android`: fork do moonlight-android.
- **Release única** em `gabs-remote` com: `GabsRemote-Setup-x.y.z.exe`, `GabsRemote-x.y.z.apk`, `manifest.json` (versões, SHA-256, versão mínima compatível entre host e app, notas) e `manifest.json.sig`.
- **Assinatura própria:** um par de chaves Ed25519 do Gab (fora do repositório). O updater só instala o que bate com o SHA-256 do manifesto assinado. Isso protege mesmo sem certificado de assinatura de código do Windows: na primeira instalação o Windows mostra o aviso do SmartScreen, como no vagabs.
- **Host:** o updater confere ao iniciar e a cada 24 h, mostra as notas na bandeja, baixa, verifica e instala em silêncio quando não há sessão ativa. O serviço reinicia sozinho e as configurações ficam em `%ProgramData%\GabsRemote`, fora da pasta do programa.
- **App:** confere ao abrir; mostra as notas; baixa o APK, verifica e instala por `PackageInstaller`.
  - O APK é sempre assinado com a mesma keystore do Gab, guardada fora do repositório com backup (onde fica cada cópia: `docs/segredos.md`, criado na fase 2).
  - O `applicationId` é definido na fase 2 e **não muda depois da primeira Release**: trocar o ID faz o Android tratar o app como outro, e o updater deixa de funcionar (decisão 0002).
  - Na primeira instalação o Android pede para permitir "instalar apps desta fonte". Depois que o próprio app for o instalador registrado, as atualizações podem ser feitas com menos toques (Android 12+ `USER_ACTION_NOT_REQUIRED`).
- **Compatibilidade:** o manifesto diz a versão mínima de cada lado. Se host e app forem incompatíveis, o app avisa e oferece atualizar antes de conectar.
- **CI:** GitHub Actions compila o host (Windows) e o APK e gera o rascunho da Release. Publicar é sempre ação do Gab.

## 9. Organização, testes e qualidade

### 9.1 Estrutura do repositório principal
```
gabs-remote/
  host/        → submódulo gabs-remote-host (fork Sunshine)
  android/     → submódulo gabs-remote-android (fork moonlight-android)
  drivers/     → tela virtual, microfone virtual, webcam virtual (código ou binários assinados + instalação)
  updater/     → updater do host, ferramenta de assinatura do manifesto
  installer/   → script do instalador (NSIS/WiX)
  web/         → presença na hospedagem (PHP) e, na fase 8, cliente web
  tools/       → medidor de latência, scripts de build
  docs/        → specs, planos, decisões, diário (em pt-BR)
  graphify-out/ → grafo do projeto para o Claude
  CLAUDE.md
```

### 9.2 Testes
- Testes do upstream continuam rodando no CI.
- Testes unitários para cada módulo novo (canal de dados, manifesto e assinatura, WoL, perfis, fila de mídia).
- Testes de integração no PC: sessão LAN automatizada (conectar, trocar perfil, desconectar, conferir resolução restaurada).
- Teste manual guiado por fase (checklist em `docs/`) no Tab S10+.

### 9.3 Medidor de latência
- O host desenha um carimbo de tempo/contador piscante num canto da tela virtual. O app lê o quadro decodificado e calcula captura→exibição, usando relógio sincronizado por ping.
- Modo "clique-até-imagem": o app envia o toque e mede quando o pixel muda.
- Relatório com média, p95 e quedas, para comparar versões e caminhos de rede (e com o Acesso Remoto do Google, à mão por vídeo em câmera lenta).

### 9.4 Graphify
O grafo do projeto (`graphify-out/`) é gerado e atualizado a cada fase, para o Claude achar rápido onde mexer nos forks grandes. O `CLAUDE.md` diz como consultá-lo.

## 10. Fases (cada uma ganha plano próprio)

O Gab usa o sistema quase sempre **fora de casa**, então o acesso externo vem logo depois do streaming básico, e não no fim. A latência em casa continua servindo de referência técnica (é o melhor caso), mas o critério que importa é o de fora.

| Fase | Entrega | Pronto quando |
|---|---|---|
| 1. Ambiente e forks | Ferramentas instaladas, repositórios criados, host e app compilando sem mudanças, base reconfirmada | O build original conecta do Tab ao PC |
| 2. Streaming (casa e fora) | Marca Gabs Remote (nome, ícone, cores e `applicationId` definitivo; sem layout próprio), perfis de resolução com tela virtual, 120 fps, S Pen completa, modos de toque, teclado, serviço com início automático, medidor de latência; **acesso de fora já via Tailscale** | Critérios 2–4 e 6 atendidos; sessão funcionando no 4G/5G pelo Tailscale |
| 3. Fora de casa completo | Escolha automática do caminho (IPv6 → port forward → Tailscale), presença na hospedagem, WoL de casa e de fora, 2º fator, bloqueio ao desconectar, reconexão na troca de rede | Critério 1 medido fora de casa; PC ligado de fora e sessão estável no 4G/5G |
| 4. Atualização e CI | Updater do host e do app, manifesto assinado, Actions, primeira Release | Critério 7 testado com duas versões reais |
| 5. Áudio, mic, clipboard, arquivos | Driver de mic, uplink de mic, clipboard, arquivos, ações remotas | Critério 5 (exceto câmera) |
| 6. Webcam | Uplink de câmera, webcam virtual DirectShow | Câmera do tablet em Meet/Discord/OBS |
| 7. Extras | Layout próprio das telas do app, segundo monitor, perfis por app, barra personalizável, mesa digitalizadora, privacidade | Cada extra com checklist próprio |
| 8. Cliente web | Gateway WebRTC + página no domínio | Sessão pelo navegador do notebook |

## 11. Riscos e decisões em aberto
- **CGNAT da Vivo:** se houver CGNAT e não houver IPv6 utilizável, o caminho remoto padrão é Tailscale (§5.2). Conferir na fase 3.
- **Drivers no Windows 10:** os drivers de tela, mic e webcam precisam ser assinados. Usar drivers já assinados (VirtualDrivers, SudoVDA). Driver próprio só se for inevitável, e então com test-signing apenas no PC do Gab.
- **4:4:4 no Tab S10+:** depende do decodificador. Conferir na fase 2.
- **Divergência do upstream:** manter as mudanças em módulos e commits pequenos para facilitar merges do Sunshine e do Moonlight. Merge do upstream a cada release estável deles.
- **Conflito com Parsec/SuperDisplay** já instalados: conferir na fase 2 se os drivers de tela virtual convivem. Desinstalar só com o ok do Gab.
- **WoL de fora de casa:** descobrir na fase 3 qual mecanismo a Alexa usa hoje (skill, app do roteador, serviço) para o app chamar o mesmo; se não der para reaproveitar, usar port forward para broadcast ou um aparelho da rede via Tailscale.
- **Sem VPS hoje** (confirmado em `docs/resposta servidor.md`): o relay próprio (§5.2 item 4) fica condicionado a contratar uma VPS. A presença na hospedagem usa só HTTPS/PHP, sem atrapalhar o site, o Vagabs e o executor que já rodam lá.
