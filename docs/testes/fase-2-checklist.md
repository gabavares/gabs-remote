# Fase 2: checklist

Fase 2 (streaming em casa e fora pelo Tailscale) testada no Galaxy Tab S10+ em 07/11/2026, com o host como serviço e o app de release. Cada critério da spec (§1.1) que a fase cobre, com a evidência; o detalhe de cada teste vem depois.

## Critérios da spec

| Critério | Resultado | Evidência |
|---|---|---|
| 2. Imagem: texto nítido em IDE e Figma em movimento; 60/90/120 fps escolhíveis | ✓ | Gab rolou o VS Code e o Figma a 120 fps sem borrão; medições a 60, 90 e 120 fps abaixo |
| 3. Resolução: tela na resolução do tablet sem barras; perfis fixos; resolução original de volta ao desconectar e depois de matar o host | ✓ | Perfis (Task 6); host derrubado no meio da sessão: os monitores voltam sozinhos (abaixo) |
| 4. Entrada: S Pen completa, toque direto e trackpad, teclado com todos os atalhos | ✓ | `docs/testes/fase-2-entrada.md` (Task 8) |
| 6. Disponibilidade (parte da fase 2): sessão na tela de login e no UAC; serviço volta sozinho | ✓ | Task 4 abaixo. WoL e reconexão automática são da fase 3 |
| Fora de casa: sessão no 4G/5G pelo Tailscale | ✓ com ressalva | Funciona; qualidade limitada pelo 4G do Gab (o Google Remote Desktop ficou igual ou pior); fora de casa o Gab usa Wi-Fi |
| Parsec e SuperDisplay ativos: qual saída o Espelhar usa (pendência da fase 1) | ✓ | Com os dois apps abertos, o Espelhar mostra o monitor principal (TCL, 2560×1440) |
| Linha de base para a fase 3: clique até a imagem | registrado | Em casa a 120 fps: média 32 ms, p95 39 ms (meta do critério 1: ≤ 30 ms em média; fica para a fase 3). Fora: não medido com números (4G ruim) |

## Medições com a tela em movimento (Task 11 Step 2, 07/11/2026, em casa, Wi-Fi)

Vídeo do YouTube tocando na tela; estatísticas do app (média da sessão) e medidor de carimbo (captura até a exibição, 10 s, ~1190 amostras, 0 perdidas). CSVs em `docs/testes/fase-2-latencia/`.

| Perfil | FPS recebidos / renderizados | Quadros perdidos | Latência de rede | Processamento no host (médio) | Decodificação (média) | Carimbo: média / p95 / máx. |
|---|---|---|---|---|---|---|
| Nativo 100% a 60 fps | 60,2 / 59,7 | 0 % | 8–10 ms | 2,8 ms | 11–13 ms | 50,1 / 59 / 90 ms |
| Nativo 100% a 90 fps | 90,0 / 88,0–89,9 | 0 % | 9–11 ms | 2,8–2,9 ms | 5,7–6,6 ms | 37,0 / 46 / 88 ms |
| Nativo 100% a 120 fps | 117,3–120,1 / 117,3–119,6 | 0 % | 7–10 ms | 2,8–2,9 ms | 0,4–0,6 ms | 28,7 / 30 / 63 ms |
| Espelhar a 120 fps | — | — | — | — | — | sessão aberta, sem captura das estatísticas |

Decodificador: `c2.mtk.hevc.decoder.lowlatency` em todas. O tempo de decodificação cai com a taxa de quadros (o decodificador da MediaTek entrega mais rápido quando recebe quadros mais seguidos); a latência total cai junto: 120 fps é o perfil indicado. Clique até a imagem a 120 fps: 32,0 ms de média (medido mais cedo, abaixo).

## Host derrubado no meio da sessão (Review Focus 2, 07/11/2026)

`sunshine.exe` finalizado pelo Gerenciador de Tarefas durante uma sessão Nativo: o serviço o subiu de novo, o driver removeu a tela virtual (watchdog) e o host novo restaurou os três monitores físicos na partida (`Recovered display topology after original devices disappeared`), sem registro sobrando. A sessão seguinte abriu normalmente. ✓

## Host como serviço (Task 4, 07/11/2026)

| Verificação | Resultado |
|---|---|
| Sem login, o tablet acha o PC e abre a sessão na tela de login do Windows | ✓ |
| Já logado, o prompt do UAC aparece no tablet e aceita toque | ✓ |
| `sc.exe qc GabsRemote`: `AUTO_START`, conta `LocalSystem` | ✓ |
| `sc.exe qfailure GabsRemote`: reiniciar após 5 s, 5 s e 30 s; zera em 86400 s | ✓ |
| `sunshine.exe` finalizado no Gerenciador de Tarefas volta sozinho em até 5 s | ✓ |

## Marca no app (Task 2, 07/11/2026)

| Verificação | Resultado |
|---|---|
| `aapt2 dump badging` do APK de release: `package: name='com.gabtavares.gabsremote'`, `application-label:'Gabs Remote'` | ✓ |
| Tablet sem o Moonlight (Debug); Gabs Remote com nome e ícone certos | ✓ |

## Sessão (pedidos do Gab, 07/11/2026)

| Verificação | Resultado |
|---|---|
| Alt+Tab ou Home no tablet: o PC continua com a tela virtual e o teclado; voltar reaproveita a tela (log: `reusing the virtual display`) | ✓ |
| Voltar ou Desconectar no menu: o PC volta aos monitores físicos | ✓ |
| Teclado pt-BR na sessão, depois do login e do Win+L; volta ao inglês internacional ao desconectar | ✓ |

## Perfis de tela (Task 6, 07/11/2026)

| Perfil | Tela virtual (log do host) | Resultado |
|---|---|---|
| Nativo 100% a 120 fps | 2800×1752 @ 120 | ✓ sem barras; monitores físicos voltam ao desconectar |
| Nativo 67% | 1866×1168 @ 120 | ✓ |
| Nativo 50% | 1400×876 @ 120 | ✓ |
| Fixo 1080p | 1920×1080 @ 120 | ✓ com barras pretas (aceito pelo Gab: uso raro) |
| Fixo 720p | 1280×720 @ 120 | ✓ com barras pretas (aceito pelo Gab: uso raro) |
| Espelhar monitor | nenhuma; monitores físicos restaurados antes da sessão | ✓ mostra o TCL |

Defeito achado e corrigido no teste: o padrão do teclado pt-BR (`00010416`) era compilado como o número 10416; a tela de configurações gravava "10416" e o app deixava de pedir o português. Agora o padrão é texto e um valor inválido volta ao padrão (conferido no tablet).

## Driver da tela virtual (Task 6, 07/11/2026)

| Verificação | Resultado |
|---|---|
| Host iniciado com o SudoVDA desativado: log `SudoVDA virtual display driver not found`; a sessão Nativo cai no espelhamento do TCL (2560×1440) com `virtual display unavailable; streaming the physical monitor instead` | ✓ |
| Com o host rodando, o Windows não deixa desativar o driver (o host mantém o driver aberto; evento 225 do sistema) | Esperado: para testar, parar o serviço antes |
| Driver religado: `SudoVDA ready` e tela virtual de novo | ✓ |

Defeito achado e corrigido no teste (host `eaa0d85a`): o registro de telas do upstream guardava a tela virtual como parte da configuração inicial do PC. Depois da reinstalação do host com uma sessão mantida em segundo plano, a tela sumiu e toda reversão passou a falhar (`DevicePrepFailed` nas sessões seguintes, tela virtual sobrando). Agora o arquivo nunca cita uma tela virtual, e trocar de perfil com o PC mantido desfaz a configuração antes. Conferido: sessão, Alt+Tab e Desconectar desfazem tudo sem erro e sem registro sobrando. O registro antigo foi apagado uma vez com o serviço parado.

## Medidor de latência (Task 9 Step 5, 07/11/2026, em casa, Nativo 100% a 120 fps)

| Modo | Amostras | Perdidas | Média | p50 | p95 | Máx. | Resultado |
|---|---|---|---|---|---|---|---|
| Clique (clique até a imagem) | 40 | 0 % | 32,0 ms | 33 ms | 39 ms | 43 ms | ✓ |
| Carimbo (captura até a exibição) | 1193 | 0 % | 27,4 ms | 28 ms | 37 ms | 63 ms | ✓ |

Critério: perdidas abaixo de 5 % e valores entre 5 e 200 ms. CSVs em `docs/testes/fase-2-latencia/`.

## Matriz de entrada (Task 8, 07/11/2026)

Tudo ✓ em `docs/testes/fase-2-entrada.md` (S Pen no Photoshop, Illustrator, Figma e Windows Ink; atalhos no Book Cover; modos de toque). Teclado Bluetooth não testado.

## 4:4:4 no Tab S10+ (Task 11 Step 1, 07/11/2026)

`adb shell dumpsys media.player`, perfis anunciados pelos decodificadores:

| Decodificador | Perfis |
|---|---|
| `c2.mtk.hevc.decoder.lowlatency` (o que o app usa) | Main, MainStill, Main10, Main10HDR10, Main10HDR10Plus |
| `c2.mtk.av1.decoder` (sem variante de baixa latência) | Main8, Main10, Main10HDR10, Main10HDRPlus |
| `c2.mtk.avc.decoder.lowlatency` | Main, High, High10 |

Nenhum anuncia 4:4:4 (`HEVCProfileMain444`, AV1 High/Professional, AVC High444). Conclusão: a spec fica com HEVC 4:2:0 de bitrate alto, e o modo texto 4:4:4 sai do escopo.

## Tailscale (Task 10, 07/11/2026)

| Verificação | Resultado |
|---|---|
| PC e tablet na mesma rede Tailscale; chave do PC sem expiração; interface `Tailscale` no Windows | ✓ |
| Regras `Gabs Remote Tailscale TCP/UDP` ativas em todos os perfis, só para `100.64.0.0/10` e `fd7a:115c:a1e0::/48` | ✓ |
| Do tablet, `GET /serverinfo` em `100.99.120.91:47989` responde `200 OK`; `tailscale ping` direto em 9 ms (em casa) | ✓ |
| No 4G, com o Wi-Fi desligado: PC adicionado pelo nome MagicDNS, sessões Nativo a 60 e 120 fps com 20, 35 e 50 Mbps | ✓ abre e funciona; qualidade limitada pelo 4G do Gab (o Google Remote Desktop, na mesma hora, ficou igual ou pior). Aceito pelo Gab, que usa o Wi-Fi do escritório fora de casa |
| Direto ou DERP no 4G | Não registrado (o tablet já tinha voltado ao Wi-Fi na conferência) |

Observações para a fase 3: no início das sessões (pelo Tailscale e também em casa, a 90 e 120 fps) o host registra centenas de `WSASendMsg() failed: 10022`; com o app na lista de PCs, o host registra `Unable to find MAC address for 100.99.120.91` a cada 1,5 s. Nenhum dos dois atrapalhou o uso.
