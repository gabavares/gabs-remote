# 0002 — Marca Gabs Remote, applicationId e layout

**Data:** 07/11/2026 · **Fase:** 2 · **Status:** decidida (`applicationId` confirmado pelo Gab em 07/11/2026)

## Contexto
O fork do moonlight-android ainda se chama "Moonlight", usa o ícone e as cores do upstream e o `applicationId` `com.limelight` (com o sufixo `.unofficial` no build de release). O upstream pede expressamente que forks troquem o ID. O Android identifica um app pelo `applicationId` mais a assinatura: se um dos dois mudar, a atualização vira "outro app", os dados (PCs pareados, preferências) se perdem e o updater da fase 4 não consegue instalar por cima.

## Decisão
1. **Na fase 2, a "Marca Gabs Remote" troca só nome, ícone e cores**, no app e no host (bandeja, painel web, nome do serviço). A identidade segue o **design system GAB/S** (`docs/marca/README.md`): cores dos tokens dele (`--azul` `#1b34f5` para ação, `--acido` para destaque, `--laranja` só para urgência) e ícone no estilo cartaz, com fundo azul chapado, monograma `G/R` em Archivo condensado e sombra dura.
2. **O `applicationId` definitivo é `com.gabtavares.gabsremote`** (variante `root`: `com.gabtavares.gabsremote.root`; build de debug: sufixo `.debug`, que instala ao lado). O `namespace` Java continua `com.limelight`, para não espalhar diferença pelo código e facilitar o merge do upstream.
3. **O `applicationId` não muda depois da primeira Release.** Qualquer proposta de troca depois disso precisa de nova decisão e de um plano de migração dos dados.
4. **O layout próprio das telas** (lista de PCs, configurações, barra da sessão com visual Gabs Remote) **fica para a fase 7.** Até lá o app usa as telas do upstream; o que a fase 2 precisa de interface nova na sessão usa componentes padrão do Android (menu pop-up, diálogo), sem layout próprio.
5. **A keystore de release é criada na fase 2** e o Gab passa a usar no tablet o build de release assinado, para que a fase 4 atualize por cima sem reinstalar. Onde ficam a keystore e os backups: `docs/segredos.md` (só locais, nunca senhas).

## Consequências
- Quem tiver instalado o build de debug (`Moonlight (Debug)`, `com.limelight.debug`) precisa desinstalar à mão; ele não vira o Gabs Remote.
- Os merges do upstream que mexerem em `build.gradle` terão conflito nas linhas do `applicationId` e dos nomes; resolver mantendo os nossos.
