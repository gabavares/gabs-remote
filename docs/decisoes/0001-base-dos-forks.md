# 0001 — Base dos forks

**Data:** 06/11/2026 · **Fase:** 1 · **Status:** decidida

## Contexto
O Gabs Remote é fork de um host compatível com o protocolo GameStream/Moonlight e de um app Android. Antes de criar os forks, reconfirmamos se o upstream continua a melhor base ou se um fork derivado (Apollo / Artemis) está mais vivo.

Regra (plano da fase 1, Task 1): fica o upstream, **a menos que** ele não tenha commit nos últimos 90 dias **e** o fork tenha.

## Evidências (API pública do GitHub, 06/11/2026)

| Repositório | Branch padrão | Último commit | Última release | Licença | Recursos citados no README |
|---|---|---|---|---|---|
| `LizardByte/Sunshine` | `master` | 06/11/2026 | v2026.914.233613 (15/09/2026) | GPL-3.0 | virtual HID |
| `ClassicOldSong/Apollo` | `master` | 21/05/2026 | v0.4.6 (13/07/2025) | GPL-3.0 | tela virtual, caneta, clipboard |
| `moonlight-stream/moonlight-android` | `master` | 12/09/2026 | v12.2 (12/09/2026) | GPL-3.0 | caneta |
| `ClassicOldSong/moonlight-android` (Artemis) | `moonlight-noir` | 09/09/2026 | v20.2.6 (08/08/2025) | GPL-3.0 | tela virtual, caneta, clipboard |

Nenhum dos quatro está arquivado. Microfone não aparece no README de nenhum.

## Decisão
Os dois upstreams têm commit nos últimos 90 dias, então a base fica **`LizardByte/Sunshine`** (host) e **`moonlight-stream/moonlight-android`** (app); tela virtual, caneta e clipboard do Apollo/Artemis entram depois, por port, nas fases 2 e 5.
