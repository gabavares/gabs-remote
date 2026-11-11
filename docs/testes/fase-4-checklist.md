# Fase 4 — Checklist (rascunho; fecha na Task 11)

Plano: `docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md`. Decisão 0006.

## Instalador sobre a instalação da fase 3 (Task 6, 09/11/2026)
- 1ª tentativa: falhou ao parar o serviço sem mexer em nada (o NSIS do MSYS2 gera instalador de **64 bits** e o caminho `Sysnative` não existe nele). Corrigido: o PowerShell é escolhido em `.onInit`.
- Instalador interativo por cima da fase 3: ✓. Serviço `GabsRemote` automático, recuperação 5 s / 5 s / 30 s, igual a antes.
- Regras de firewall iguais às de antes: só `Gabs Remote LAN TCP/UDP` (perfil Privado, `LocalSubnet`) e `Gabs Remote Tailscale TCP/UDP` (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`; painel 47990 fora do Tailscale). ✓
- `icacls config\updates`: só `AUTORIDADE NT\SISTEMA` e `BUILTIN\Administradores`, controle total, sem herança. ✓
- `config` preservada (credentials, apps.json, sunshine.conf, sunshine_state.json). ✓ Tablet conectou sem pedir PIN (Gab). ✓
- `GabsRemote-Setup-0.4.0.exe /S /ATUALIZACAO`: código 0 em 15 s, sem janela, serviço voltou sozinho, log `Sunshine version: 0.4.0` e `updater on (installed 0.4.0)`. ✓
- Entrada em "Aplicativos": Gabs Remote 0.4.0, Gab Tavares. ✓
- Login do painel com o mesmo usuário: pendente (conferir na Task 10).

## Updater do host em console, sem Release (Task 5)
- "Procurar atualizações" → estado `error`, "Nenhuma versão publicada ainda." no painel e `no Release published yet (HTTP 404)` no log. ✓
- Sessão aberta ao mesmo tempo sem engasgo: pendente (Task 11).

## Observação do Gab (09/11/2026)
- Tablet no 4G roteado pelo celular, pelo Tailscale: mais de 60 fps e menos de 40 ms, na mesma internet instável que antes tinha ficado ruim.

## CI (Task 9, 10/11/2026)
- 1º run: Pester falhou (stderr do OpenSSL virava exceção com `ErrorActionPreference Stop`) e o host falhou (pacotes do `qt6-static` que o upstream não lista). Corrigidos.
- 2º run (`42745627507`): tudo verde. Tempos: Presença (PHP) 10 s; Scripts (Pester) 2 min; App (testes unitários) 2,5 min; Host (build e testes, Gabs Remote + upstream) 28,6 min. ✓

## Primeira Release 0.4.0 (Task 10, 10/11/2026)
- Workflow Release (`42748908250`): rascunho com `GabsRemote-Setup-0.4.0.exe` (85,7 MB) e `GabsRemote-0.4.0-unsigned.apk`, ambos de `github-actions[bot]`. ✓
- `preparar-release.ps1`: três correções no caminho (ExecutionPolicy, leitura da chave pública no `segredos.md`, formato do `apksigner` 37), todas antes de qualquer assinatura. Resumo: versionCode 4000, certificado do APK confere, assinatura do manifesto confere. ✓
- Rascunho final: `.exe`, `.apk` assinado, `manifest.json`, `manifest.json.sig`, sem `-unsigned`; manifesto baixado e conferido de novo (assinatura e regras). Publicada às 00:46 de 10/11/2026 (horário de Brasília). ✓
- `releases/latest/download/manifest.json` responde 200 por HTTPS. ✓
- PC: instalador da Release por cima, login do painel igual, "Procurar atualizações" → **0.4.0 · Em dia**. ✓
- Tablet: mantido o APK 0.4.0 (4000) já instalado (mesmo código e assinatura do da Release).

## Segunda versão 0.4.1: cursor no tablet (Task 11, Step 1; 10/11/2026)
Motivo: no escritório, pelo Tailscale, o Gab sentiu o mouse atrasado em qualquer fps e resolução. O atraso vinha do cursor desenhado dentro do vídeo (chega com toda a latência da imagem, ~40 ms); o app já mandava o mouse sem lote (1 ms). A 0.4.1 desenha o cursor no tablet e manda a posição absoluta (`grCursor=local`); o host tira o cursor do vídeo e conta o formato pelo `/gabs/cursor`.
- Host `86804db0`, app `97d26abe`, principal `b86761c`, tag `v0.4.1`. Testes: host 12 novos (`GabsCursorTest`, 984 no total, verdes); app 21 novos (`LocalCursorTest` 15, `CursorShapePollerTest` 6, verdes).
- Workflow Release `42837612301`: verde em 14 min; rascunho com `GabsRemote-Setup-0.4.1.exe` (85,7 MB) e `GabsRemote-0.4.1-unsigned.apk` (11,2 MB).
- `preparar-release.ps1` (Gab digitou a senha): APK assinado (versionCode 4001, 11,2 MB), manifesto e `.sig` no rascunho; manifesto baixado e conferido de novo (assinatura e regras). Publicada às 12:11 de 10/11/2026 (horário de Brasília); `releases/latest/download/manifest.json` responde 200 com 0.4.1. ✓

### Critério 7 com duas versões reais
- App (0.4.0 → 0.4.1): diálogo ao abrir, toques até a 0.4.1 aberta, tempo: pendente.
- Host (0.4.0 → 0.4.1): espera com sessão aberta, instala com 0 sessões, tempo até "0.4.1 · Em dia": pendente.

### Cursor no tablet (uso real)
- Seta sem atraso no trackpad da tela, no trackpad do teclado e no mouse; formato de texto em caixa de texto e mão em link: pendente.
- Some com toque direto e caneta; reaparece ao mexer o mouse; gira com a tela: pendente.

### Primeiro uso da 0.4.1 (Gab, 10/11/2026) e correção 0.4.2
- ✗ Seta do app por cima do cursor do Windows: o PC ainda estava no host 0.4.0 (o updater espera não haver sessão), que não conhece `grCursor` e desenha o cursor no vídeo. O app devia perceber, mas o "não encontrado" do Sunshine responde HTTP 200 com `status_code="404"` no XML, e o app ficava tentando de novo com a seta ligada.
- ✗ Mouse andando menos: na posição absoluta a aceleração do Windows não age.
- Correção 0.4.2 (app `e32b8edd`, principal `0a797aa`): o cursor local só liga com a primeira resposta válida do `/gabs/cursor` (até lá e com host antigo, mouse relativo como na 0.4.0); o `status_code="404"` no corpo conta como host sem a rota; aceleração própria, ganho = 0,8 + 1,2 × velocidade (px/ms), entre 1 e 3,5. Testes do app: `LocalCursorTest` 18, `CursorShapePollerTest` 6, verdes.
- Workflow Release `42842601666`: verde; rascunho com `GabsRemote-Setup-0.4.2.exe` (85,7 MB) e `GabsRemote-0.4.2-unsigned.apk` (11,2 MB). Assinada pelo Gab (APK 11,2 MB, versionCode 4002); manifesto e assinatura conferidos (`Test-Manifesto` e `Test-AssinaturaManifesto`); publicada às 13:40 de 10/11/2026, `releases/latest/download/manifest.json` responde 0.4.2. Workflow Testes `42842595840`: verde.

### Uso da 0.4.2 (Gab, 10/11/2026) e correção 0.4.3
- ✗ Rápido demais; o Gab prefere 1 para 1 e quer a velocidade nas configurações.
- ✗ Cursor sem fluidez, pulando, com o tablet e a transmissão em 120 fps. Causa: a aceleração media a velocidade pela hora do processamento (`uptimeMillis`), não a do toque; os pontos do dedo chegam em lote no mesmo instante e o ganho oscilava entre 1 e 3,5 de um evento para o outro. A escala do trackpad da tela para a grade de 1280 x 720, com arredondamento para inteiro, piorava os passos.
- Correção 0.4.3 (app `824c5500`): sem aceleração; o trackpad da tela manda o deslocamento do dedo em pixels da tela e o cursor anda na tela o mesmo que o dedo (zoom local incluído); preferência "Velocidade do cursor" (`gr_cursor_speed`, 25% a 300%, padrão 100%) multiplica também o mouse e o trackpad do teclado. Host sem mudança. `LocalCursorTest` 21, verde.
- Workflow Release `42858568333`: verde; rascunho com `GabsRemote-Setup-0.4.3.exe` (85,7 MB) e `GabsRemote-0.4.3-unsigned.apk` (11,2 MB). Assinada pelo Gab (APK 11,2 MB, versionCode 4003, sha256 diferente da 0.4.2); manifesto e assinatura conferidos; publicada às 15:04 de 10/11/2026, `releases/latest/download/manifest.json` responde 0.4.3. Workflow Testes `42858565186`: verde.

### Uso da 0.4.3 (Gab, 10/11/2026) e ponteiro nativo na 0.4.4
- A 60% a velocidade ficou crível, mas o cursor ainda atrasava e pulava um pouco; fora do app o ponteiro do tablet é liso e sem atraso.
- Causa (trackpad do teclado e mouse): o app capturava o ponteiro (por causa da rotação do trackpad do Book Cover), recebia os dedos crus e arredondava cada evento para inteiro (`TouchpadGestures`), sem a aceleração do tablet; e o cursor do app é uma view comum, 1 ou 2 quadros atrás da camada de ponteiro do sistema. A posição não esperava o PC: o `/gabs/cursor` só conta o formato.
- 0.4.4 (app `bc481bb6`): depois que o host confirma o `grCursor`, o mouse e o trackpad do teclado deixam de ser capturados (`cursorVisible` do upstream); o Android desenha o ponteiro e o app troca o ícone por `PointerIcon` (`NativePointer.iconType`) e manda a posição por `updateMousePosition`. Rolagem de dois dedos do Android 14+ (`CLASSIFICATION_TWO_FINGER_SWIPE`) vira rolagem no PC; três ou quatro dedos e pinça ficam com o sistema. O trackpad na tela continua com o desenho do app e a "Velocidade do cursor". Testes: `LocalCursorTest` 24, `NativePointerTest` 3, verdes.
- A conferir no uso: ponteiro liso, formato mudando (texto, mão), rolagem com dois dedos no sentido certo, toque para clicar e clique direito, gestos de três dedos da Samsung.
- Workflow Release `42875385962`: verde; rascunho com `GabsRemote-Setup-0.4.4.exe` (85,7 MB) e `GabsRemote-0.4.4-unsigned.apk` (11,2 MB). Assinada pelo Gab (versionCode 4004, sha256 do APK confere com o manifesto); manifesto e assinatura conferidos; publicada às 15:51 de 10/11/2026, `releases/latest/download/manifest.json` responde 0.4.4. Workflow Testes `42875381037`: verde.
- Uso da 0.4.4 (Gab, 10/11/2026): tudo funcionando (ponteiro, formatos, rolagem, cliques, gestos). Atraso menor, mas ainda "elástico": o ponteiro é o do tablet; o que vem atrasado é a reação do Windows na imagem (destaque ao passar, janela arrastada, seleção), que segue a latência da imagem. Próximo passo: medir (clique e carimbo, `docs/latencia.md`) e afinar na Task 9 da fase 3.
- ✗ Causa real do atraso que sobrou (achada no log do host às 16h): o PC continua no host **0.4.0** (`sunshine.exe` de 10/11 00:35; log: "up to date (0.4.0)" às 08:05). O updater confere a cada 24 h e a 0.4.1 saiu às 12:11, então só veria a versão nova em 11/11 às 08:05. Com host 0.4.0, o `/gabs/cursor` não existe, o app não liga o cursor no tablet e o mouse segue capturado, com a seta do Windows dentro do vídeo. As 0.4.1 a 0.4.4 do cursor ainda não foram testadas com o host certo. Correção: "Procurar atualizações" no painel e encerrar a sessão para instalar.
- ✓ Host atualizado pelo painel ("Procurar atualizações", instalou com a sessão encerrada): log de 11/11/2026 08:53 "Sunshine version: 0.4.4". Com host e app na 0.4.4, o Gab confirmou no escritório (mouse USB no tablet): **tudo funcionando**, ponteiro do tablet na hora e só a reação do Windows com o atraso da rede. Fica 24 h de intervalo no updater do host (decisão do Gab, 10/11/2026).

