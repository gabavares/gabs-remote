# Fase 5 — Checklist (áudio, microfone, clipboard, arquivos, ações)

Plano: `docs/superpowers/plans/2026-11-11-fase-5-audio-mic-clipboard-arquivos.md`. Decisão: `docs/decisoes/0007-audio-microfone-clipboard-arquivos.md`.
Legenda: ✓ conferido · ✗ falhou · ☐ a conferir (com o que fazer).

## Preparação do PC
- ✓ VB-CABLE Pack46 instalado (11/11/2026) por `tools/setup/instalar-audio.ps1`: "Alto-falantes (VB-Audio Virtual Cable)", "CABLE Output (VB-Audio Virtual Cable)" e "CABLE In 16 Ch" presentes, saída padrão do Windows intacta. O script na primeira versão procurava "CABLE Input" (nome antigo) e acusou erro mesmo instalado; corrigido para "CABLE Output" no mesmo commit da decisão 0007.
- ✓ "Steam Streaming Speakers" presente (é o `virtual_sink`).

## Som do PC
O upstream já troca a saída padrão para o "Steam Streaming Speakers" quando `virtual_sink` está vazio e "Reproduzir áudio no PC" está desligado no app (Task 2: nenhuma mudança de código; a tradução já existia).
- ☐ Sessão com "Reproduzir áudio no PC" **desligado**: vídeo no PC soa no tablet e **não** nas caixas; no log do host, troca para o Steam Streaming Speakers; ao desconectar, a saída padrão volta a ser a de antes.
- ☐ Com a opção **ligada**: toca nos dois.

## Microfone
- ☐ (Task 4) Tom de 440 Hz do teste `DISABLED_MicService.LiveToCable` aparece na barra de nível do "CABLE Output" (`mmsys.cpl` → Gravação).
- ☐ (Task 5) Ligar o microfone pelo menu da sessão, falar e ver o nível do "CABLE Output"; gravar 10 s no Gravador de Som e ouvir. Home → ponto verde some; voltar → microfone volta.
- ☐ (Task 6) Chamada real (Meet no Chrome do PC com "CABLE Output" como microfone): o outro lado ouve sem eco com o som do PC tocando no tablet; atraso percebido e qualidade. Repetir pelo Tailscale se der.

## Clipboard
- ☐ (Task 9) texto e imagem nos dois sentidos, laço, grande demais, modo manual.

## Arquivos
- ☐ (Task 13) arquivo grande nos dois sentidos com queda de rede no meio; nomes hostis; permissão do usuário.

## Ações do PC
- ☐ (Task 13) bloquear, suspender (acordar pelo WoL), reiniciar (host volta sozinho), desligar (ligar pelo WoL).

## Review Focus
- ☐ 1. Eco e retorno no microfone.
- ☐ 2. Rede ruim no 4G pelo Tailscale.
- ☐ 3. Segundo plano, fim de sessão e queda de rede com o microfone ligado.
- ☐ 4. Clipboard em laço ou gigante.
- ☐ 5. Nomes e transferências hostis ou interrompidas.
