# 0006 — Atualização automática e Release

**Data:** 09/11/2026 · **Fase:** 4 · **Status:** decidida pelo Gab (09/11/2026)

## Contexto
A spec (§8) pede uma Release única no `gabavares/gabs-remote` com instalador do host, APK, `manifest.json` e `manifest.json.sig`, conferidos por uma chave Ed25519 do Gab, e updaters no host e no app (critério 7). Ao planejar a fase 4 apareceram escolhas que a spec deixava em aberto ou que o código dos forks muda: onde assinar, como numerar versões, se o updater do host é um executável à parte, onde fica a configuração e qual instalador usar.

## Decisão
1. **Assinaturas só no PC do Gab.** O CI (GitHub Actions) não recebe a keystore nem a chave Ed25519, nem como *secret* do GitHub. Ele gera o instalador e um APK **sem assinatura** num rascunho de Release; `tools/release/preparar-release.ps1` assina o APK, monta e assina o manifesto no PC do Gab e sobe para o rascunho. Quem tomar a conta do GitHub não consegue publicar sozinho uma atualização que os updaters aceitem. A chave prova que o Gab aprovou o manifesto, não que conferiu o binário; por isso o `preparar-release.ps1` só assina se o rascunho ainda for rascunho, se os arquivos foram enviados pelo CI (`github-actions[bot]`), se a tag no GitHub aponta para o mesmo commit da tag no PC do Gab e se o workflow Release terminou com sucesso nesse commit (revisão final da fase 4).
2. **Versão única do sistema** `x.y.z` para host, app e Release, no `versao.json` da raiz do principal, começando em **0.4.0**. Tag `vx.y.z`. `versionCode` do APK = `major·1 000 000 + minor·1 000 + patch` (0.4.0 → 4000, maior que o 315 do upstream); cada parte vai de 0 a 999. O `versao.json` também guarda a versão mínima do app que o host aceita (`minApp`) e a do host que o app aceita (`minHost`).
3. **O updater do host vive dentro do host** (`host/src/gabs/update_*`), e não num executável à parte como a spec (H7) previa: o host já tem curl, OpenSSL, a bandeja, o painel e a contagem de sessões. O instalador é lançado fora do job object do serviço (`CREATE_BREAKAWAY_FROM_JOB`, que o job do `sunshinesvc` permite), para sobreviver à parada do serviço.
4. **A configuração continua em `C:\Program Files\Gabs Remote\config`**, como desde a fase 2, e não em `%ProgramData%\GabsRemote` (spec §8). O instalador nunca toca nessa pasta. Os downloads vão para `config\updates\`, que só Administradores e SYSTEM podem gravar.
5. **Instalador NSIS próprio** em `installer/`, e não o WiX/cpack do upstream (que cria o serviço e as regras de firewall do Sunshine, abertas para qualquer rede). O instalador cria o serviço `GabsRemote` e só as regras `Gabs Remote LAN *` e `Gabs Remote Tailscale *` (decisão 0005).
6. **CI só no principal.** Os workflows do upstream nos forks ficam como estão e desligados (Actions não habilitadas nos forks).
7. **Publicar:** o Claude faz commit, push, tag, rascunho e publicação da Release do Gabs Remote sem pedir (Gab, 09/11/2026). As senhas da keystore e da chave Ed25519 quem digita é o Gab, no terminal.

## Consequências
- O CI nunca publica nada sozinho: sem o `preparar-release.ps1` no PC do Gab, o rascunho fica com o APK sem assinatura e sem manifesto, e nenhum updater o aceita.
- **Perder a chave Ed25519** = os updaters param de aceitar versões novas; é preciso reinstalar à mão o host e o app com uma chave nova embutida. Por isso ela tem as mesmas três cópias da keystore (`docs/segredos.md`).
- Atualizações silenciosas do host rodam como SYSTEM e não passam pelo SmartScreen; só a primeira instalação manual mostra o aviso.
- O host passa a informar `GabsVersion` e `GabsMinApp` no `/serverinfo`; host anterior à fase 4 não tem esses campos, e o app conecta como antes.
- Código: `versao.json`, `tools/release/`, `installer/`, `.github/workflows/`, host `src/gabs/update_*`, app `gabs/update/`.
