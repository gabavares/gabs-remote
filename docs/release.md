# Como fazer uma Release do Gabs Remote

Decisão 0006: o CI compila sem segredos e cria um **rascunho**; as assinaturas (APK e manifesto) só acontecem no PC do Gab. Os updaters do host e do app só aceitam o que vier com `manifest.json` assinado pela chave Ed25519 de `docs/segredos.md`.

## Passo a passo

1. **Versão e notas.** Edite `versao.json` (`version`, e `minApp`/`minHost` se a nova versão não conversar com as anteriores) e escreva `docs/notas/<versão>.md` em pt-BR (Markdown simples; vira o texto do diálogo do app e do painel).
2. **Commit e push** do principal (e dos submódulos, se mudaram).
3. **Tag:**
   ```powershell
   git tag v<versão>
   git push origin v<versão>
   ```
   O workflow **Release** (`.github/workflows/release.yml`) confere que a tag é `v` + `versao.json`, compila o host e o instalador (`GabsRemote-Setup-<versão>.exe`) e o APK sem assinatura (`GabsRemote-<versão>-unsigned.apk`), e cria o rascunho. Leva cerca de 40 minutos. Acompanhe com `gh run watch` ou em github.com/gabavares/gabs-remote/actions.
4. **Assinar no PC** (o Gab digita a senha da chave do manifesto; a da keystore vem do `keystore.properties`):
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\gr\tools\release\preparar-release.ps1 -Versao <versão>
   ```
   (`-ExecutionPolicy Bypass` vale só para esse comando: o Windows bloqueia scripts por padrão.) Confira o resumo (versão, tamanhos, SHA-256, "certificado confere", "assinatura confere").
5. **Subir para o rascunho:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\gr\tools\release\preparar-release.ps1 -Versao <versão> -Enviar
   ```
   No rascunho ficam: `GabsRemote-Setup-<versão>.exe`, `GabsRemote-<versão>.apk` (assinado), `manifest.json`, `manifest.json.sig`. O `-unsigned.apk` é apagado.
6. **Publicar:**
   ```powershell
   gh release edit v<versão> --repo gabavares/gabs-remote --draft=false
   ```
   A partir daí o app oferece a versão ao abrir, e o host baixa em até 24 h (ou na hora, pelo painel: Procurar atualizações) e instala quando não houver sessão.

## Se algo der errado
- **Tag errada / versão diferente do `versao.json`:** o workflow para no primeiro job. Apague a tag (`git push origin :refs/tags/v<versão>` e `git tag -d v<versão>`), corrija e repita.
- **Rascunho já existe:** rodar o workflow de novo (Actions › Release › Run workflow com a tag) substitui o instalador e o APK sem assinatura; uma Release **publicada** nunca é alterada pelo CI.
- **"O APK foi assinado com outro certificado":** pare. A keystore não é a de `docs/segredos.md`.
- **Publicou algo errado:** não dá para voltar versão (o updater ignora versões menores ou iguais). Publique uma correção com a versão seguinte.
- **Atualização silenciosa do host não aconteceu:** log do host (`C:\Program Files\Gabs Remote\config\sunshine.log`, linhas `Gabs Remote: ...`) e o log do instalador em `C:\Windows\Temp\gabs-remote-configurar.log`.

## Testes do CI
O workflow **Testes** (`.github/workflows/testes.yml`) roda a cada push em `main`: testes unitários do app, Pester dos scripts (exceto os marcados `Local`), testes da presença (PHP) e o build do host com as suítes do Gabs Remote (as do upstream rodam como informativas).
