# 0007 — Áudio, microfone, clipboard e arquivos

**Data:** 11/11/2026 · **Fase:** 5 · **Status:** decidida (plano da fase 5 revisado pelo Gab; drivers conferidos e VB-CABLE instalado em 11/11/2026)

## Contexto
A spec (§4.1 H3 e H5, §6.3, §6.5) pede o som do PC no tablet, o microfone do tablet como microfone do Windows, clipboard e arquivos nos dois sentidos e comandos de energia. O protocolo do Moonlight não tem microfone, a spec supunha que o microfone do Virtual-Audio-Driver aceitava áudio de fora, e o Windows 10 só aceita driver assinado.

## Decisão
1. **Transporte próprio do microfone, sem mexer no `moonlight-common-c`.** As propostas do upstream (moonlight-common-c#123, #173) não estão mergeadas nem combinam entre si. O app manda um quadro Opus por pacote UDP para a porta 48002 do PC (já liberada nas regras `Gabs Remote LAN/Tailscale UDP`), cifrado em AES-128-GCM com a chave da sessão (`rikey`). Formato no plano da fase 5, seção "Formatos".
2. **Driver do microfone: VB-CABLE** (VB-Audio). O Virtual-Audio-Driver 25.7.14 não serve: o microfone dele vem do exemplo Sysvad e só entrega silêncio — `Source/Main/minwavertstream.cpp`, `CMiniportWaveRTStream::WriteBytes` (linha 1392 no `main` de 11/11/2026) faz `RtlZeroMemory` no buffer de captura, sem pipe, memória compartilhada nem IOCTL por onde outro processo escreveria.
   - Pacote: `https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack46.zip`, SHA-256 `bc44e8974191a5a2427d6c979e2dab08dbb09925f3f435dfa2f0ba3e45b6eb90` (1 324 680 bytes). Catálogo `vbaudio_cable64_win10.cat` assinado pela Microsoft Windows Hardware Compatibility Publisher; `VBCABLE_Setup_x64.exe` assinado por BUREL VINCENT (Authenticode válido).
   - No Windows 10 pt-BR do Gab, a versão 46 cria três endpoints: **"Alto-falantes (VB-Audio Virtual Cable)"** (Reprodução: é onde o host escreve), **"CABLE Output (VB-Audio Virtual Cable)"** (Gravação: o microfone que o Meet e o Discord usam) e "CABLE In 16 Ch (VB-Audio Virtual Cable)" (Reprodução, 16 canais, não usado). O nome "CABLE Input" das versões antigas não existe mais.
   - É *donationware*: não vai dentro do instalador. `tools/setup/instalar-audio.ps1` baixa o pacote oficial, confere o SHA-256 e instala uma vez, como administrador.
3. **Caixas do PC em silêncio** pela opção do upstream "Tocar som no PC" (desligada), com o host trocando a saída padrão durante a sessão para o **"Steam Streaming Speakers"** (já instalado pelo Steam no PC do Gab). Esse nome vira o padrão de `virtual_sink`. Nenhum driver de alto-falante vai no instalador.
4. **Microfone começa mudo em toda sessão.** O Gab liga pelo menu da sessão; a preferência "Microfone ligado ao conectar" (desligada) muda isso. Indicador: o ponto verde do Android mais o texto do item do menu. Com o app em segundo plano (decisão 0004) o microfone **para**.
5. **Clipboard automático por padrão** ("Clipboard automático", ligada), só durante a sessão, até 1 MiB de texto e 16 MiB de imagem PNG. Desligado, o menu da sessão tem "Mandar clipboard ao PC" e "Trazer clipboard do PC".
6. **Arquivos:** "Enviar para o PC" (compartilhar do Android) funciona sem sessão aberta, com o PC ligado e pareado, para `Downloads\Gabs Remote` do usuário logado. "Enviar para o tablet" (Enviar para do Explorer) põe o arquivo numa fila que o app busca enquanto a sessão está aberta, e salva em `Download/Gabs Remote`.
7. **Ações remotas** pelo menu da sessão: bloquear, suspender, reiniciar e desligar (desligar completo, sem o Início rápido, por causa do WoL). As três últimas pedem confirmação.

## Consequências
- Reinstalar o Windows = rodar `powershell -ExecutionPolicy Bypass -File C:\gr\tools\setup\instalar-audio.ps1` de novo, como administrador. Se a VB-Audio trocar o pacote, o script recusa (código 3) e o hash precisa ser atualizado.
- O microfone aparece no Windows como "CABLE Output (VB-Audio Virtual Cable)", não "Microfone Gabs Remote": renomear o endpoint exige mexer no registro protegido do serviço de áudio (fora da fase 5).
- O nome do endpoint de reprodução depende do idioma do Windows ("Speakers (VB-Audio Virtual Cable)" em inglês). O host procura pelo nome configurado em `gr_mic_sink`, cujo padrão é `VB-Audio Virtual Cable`, e ignora o endpoint de 16 canais.
- Sem o Steam, as caixas do PC não ficam em silêncio (o script avisa); a saída seria instalar o Steam ou um alto-falante virtual assinado.
- Nenhuma porta nova (decisão 0005): microfone na UDP 48002, clipboard, arquivos e ações na 47984, com o certificado do pareamento. O app só mostra o que o host anuncia em `GabsFeatures` no `/serverinfo`.
