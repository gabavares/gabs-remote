# 0003 — Driver da tela virtual

**Data:** 07/11/2026 · **Fase:** 2 · **Status:** decidida (escolha confirmada pelo Gab em 07/11/2026)

## Contexto
O upstream do Sunshine não cria tela virtual. Para o perfil "Nativo do tablet" (2800×1752 a até 120 Hz), o host precisa criar um monitor com a resolução e a taxa pedidas pelo cliente e removê-lo no fim da sessão, inclusive se o host cair. A spec (H2) lista dois candidatos, e o Windows 10 exige driver assinado.

Regra do plano da fase 2 (Task 1): fica o **SudoVDA**, a menos que ele não instale assinado no Windows 10 22H2 ou não crie 2800×1752 a 120 Hz.

## Candidatos (levantados em 07/11/2026)

| | **SudoVDA** (`SudoMaker/SudoVDA`) | **Virtual-Display-Driver** (`VirtualDrivers/Virtual-Display-Driver`) |
|---|---|---|
| Licença | MIT (mudanças: CC0) | MIT |
| Versão | 1.10.9.289 (INF de 14/07/2025), protocolo IOCTL 0.2.1 | 25.7.23 (23/07/2025) |
| Onde obter | **sem release própria**: a DLL só sai no instalador do Apollo (`Apollo-0.4.6.exe`, pasta `drivers\sudovda`) | releases no GitHub, com instalador e app de controle |
| Assinatura | catálogo e DLL assinados com certificado **próprio** (`CN=sudovda@su.mk`, só uso "Assinatura de código", válido até 13/07/2030). A instalação importa esse certificado em Raiz e Editores Confiáveis do Windows; não precisa de test-signing | assinado pela SignPath Foundation (CA pública) |
| Criar monitor sob demanda | sim: `IOCTL_ADD_VIRTUAL_DISPLAY` com largura, altura e taxa (mHz) quaisquer e um GUID por monitor | não: resoluções fixas no `C:\VirtualDisplayDriver\vdd_settings.xml`; o pipe `MTTVirtualDisplayPipe` só tem `SETDISPLAYCOUNT`, `RELOAD_DRIVER`, `PING` |
| Remover | `IOCTL_REMOVE_VIRTUAL_DISPLAY` por GUID | `SETDISPLAYCOUNT 0` (todos) |
| Watchdog | sim: sem `IOCTL_DRIVER_PING` por 3 s (padrão), o driver remove os monitores | não |
| Código pronto para portar | Apollo `src/platform/windows/virtual_display.cpp` (GPL-3.0) e `third-party/sudovda/` | — |

## Decisão
**SudoVDA 1.10.9.289.** Cria o monitor por cliente com a resolução e a taxa pedidas e tem watchdog, que é o que a Review Focus 2 do plano precisa (host morto no meio da sessão). A assinatura não é de CA pública: o Gab aceitou confiar no certificado da SudoMaker (07/11/2026). O certificado só vale para assinatura de código, então não serve para emitir outros certificados.

O pacote do driver fica versionado em `drivers/sudovda/`, porque não há release própria e o instalador da fase 4 vai precisar dele.

| Arquivo | SHA-256 |
|---|---|
| `SudoVDA.dll` | `47EE263CB5DE9382C6630A2D7F3DAFEC4A49419F953BEEC869CA5DD0C460FF63` |
| `SudoVDA.inf` | `AD69AC682756F0CF339B081FAC7E6E8159FDF2CA01CA69DF8945C7246C286925` |
| `sudovda.cat` | `2F9189DE5604BEC9D86F51640CC540639E394D9AD0F8E689129375E95F2D22F8` |
| `sudovda.cer` | `6ACCDCD519F6179D967DB4EAA20ECF25A732BA30E87F4CFFEBC768B2C13C9007` (SHA-1 do certificado: `3C918FC73525AD8B1521B6DB26B71F694277CC49`) |
| `nefconc.exe` | `9DBA1F1A9E2B21843C4A0CA6C6FFA9E747250DD6E42C8C14325CA069AD43EA8F` (assinado pela Nefarius Software Solutions) |
| `install.bat` / `uninstall.bat` | `1453B042…C219` / `EBACFADC…046B` |

Origem: `https://github.com/ClassicOldSong/Apollo/releases/download/v0.4.6/Apollo-0.4.6.exe`, SHA-256 `42b2aefaacb3474511517a56b96ee9f0517f30ac38b5dd2fda9fd5b478f5021a` (igual ao `digest` publicado pelo GitHub), extraído com o 7-Zip.

## Como o host chama a API
Cabeçalhos do Apollo em `third-party/sudovda/` (`sudovda-ioctl.h`, `sudovda.h`, MIT). Interface do dispositivo `{e5bcc234-1e0c-418a-a0d4-ef8b7501414d}`, aberta com `SetupDiGetClassDevs` + `CreateFile`. Qualquer usuário pode abrir (o INF dá leitura e escrita a todos), então o serviço `GabsRemote` (SYSTEM) e o host em console funcionam.

| IOCTL | Entrada → saída | Uso no host (`driver_t`) |
|---|---|---|
| `IOCTL_GET_PROTOCOL_VERSION` (0x8FF) | → versão | `available()`: abre o dispositivo e confere a versão |
| `IOCTL_ADD_VIRTUAL_DISPLAY` (0x800) | `{Width, Height, RefreshRate em mHz, GUID, DeviceName[14], SerialNumber[14]}` → `{AdapterLuid, TargetId}` | `add()`: o GUID é UUID v5 do `client_uid`; o nome GDI (`\\.\DISPLAYn`) sai de `QueryDisplayConfig` pelo `TargetId` |
| `IOCTL_REMOVE_VIRTUAL_DISPLAY` (0x801) | `{GUID}` | `remove()` |
| `IOCTL_DRIVER_PING` (0x888) | — | `keep_alive()`, a cada 1 s |
| `IOCTL_GET_WATCHDOG` (0x803) | → `{Timeout, Countdown}` | log |

`remove_all()` (limpeza na subida do host): o driver não tem "remover todos"; como o watchdog remove sozinho os monitores de um host que morreu, a limpeza na subida só precisa reverter a configuração de tela salva (`display_device`) e remover o GUID conhecido do cliente, se houver.

## Convivência com Parsec e SuperDisplay
Instalado em 07/11/2026 com os dois ativos: o Gerenciador de Dispositivos mostra os três adaptadores (`Parsec Virtual Display Adapter`, `SudoMaker Virtual Display Adapter`, `SuperDisplay Virtual Adapter`) com status OK. O `dxgi-info` continua listando as três saídas físicas na RTX 5060 Ti (`DISPLAY1` 2560×1440 @ 180 Hz, `DISPLAY2` 4096×2160 @ 120 Hz, `DISPLAY3` 1080×1920 @ 60 Hz). Teste com `tools/setup/testar-tela-virtual.ps1`: monitor `\\.\DISPLAY22` em **2800×1752 @ 120 Hz** criado e removido, monitores físicos inalterados.

## Consequências
- Atualizar o driver = extrair a nova versão do instalador do Apollo, conferir hashes e assinatura, e atualizar esta decisão.
- Se a SudoMaker trocar o certificado, o Gab precisa aceitar o novo.
- Desinstalar: `drivers\sudovda\uninstall.bat` como administrador (o certificado continua no repositório de certificados até ser removido à mão em `certlm.msc`).
