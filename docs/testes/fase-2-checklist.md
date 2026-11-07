# Fase 2: checklist (rascunho)

Rascunho das verificações feitas no tablet. A Task 11 transforma este arquivo no checklist final, com os critérios da spec.

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
