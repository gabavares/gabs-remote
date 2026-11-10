# Segredos do Gabs Remote: onde ficam

Este arquivo registra **onde** ficam os segredos e as cópias deles. Senhas e chaves **nunca** entram aqui, no repositório ou na conversa com o Claude.

## Keystore de release do app (fase 2)

O Android só atualiza o app por cima se a assinatura for a mesma. Perder a keystore = o Gabs Remote do tablet não recebe mais atualização; vira desinstalar e parear de novo.

| Cópia | Onde | O que tem |
|---|---|---|
| **Original** | `%USERPROFILE%\.gabs-remote\` | `gabs-remote-release.jks` + `keystore.properties` |
| **Backup 1, nuvem** | Google Drive do Gab, pasta `Gabs Remote/segredos/` | `gabs-remote-segredos.7z` (7-Zip, AES-256, cabeçalho cifrado) |
| **Backup 2, offline** | pendrive guardado em casa | o mesmo `gabs-remote-segredos.7z` |
| **Senhas** | gerenciador de senhas do Gab, item "Gabs Remote — keystore" | senha da keystore, da chave e do `.7z` |

- Alias da chave: `gabs-remote` (RSA 4096, validade 10000 dias, `CN=Gabs Remote, O=Gab Tavares, C=BR`).
- Criada em 07/11/2026.
- Impressão SHA-256 do certificado (a mesma que `apksigner verify --print-certs` mostra no APK): `17:0F:8C:18:2D:A2:84:C1:01:2F:35:42:5E:40:45:FF:C7:AD:4E:C6:C9:8F:48:5B:FF:94:9A:7C:8F:26:7F:49`
- SHA-256 do arquivo `gabs-remote-release.jks`: `D82BC14E24BFF297D2A1483F711463A7DCC0090CF380CAE754888A617A913F0D`
- Backups no Drive e no pendrive: feitos pelo Gab em 07/11/2026.
- Teste do backup: **pendente**. Baixar o `.7z` do Drive, extrair numa pasta temporária, rodar `Get-FileHash <pasta>\gabs-remote-release.jks` e comparar com o SHA-256 acima; apagar a pasta e anotar a data aqui.

### Formato do `keystore.properties`

```properties
storeFile=gabs-remote-release.jks
storePassword=<senha da keystore>
keyAlias=gabs-remote
keyPassword=<senha da chave>
```

`storeFile` relativo vale a partir da pasta do próprio `keystore.properties`. O `build.gradle` lê o arquivo de `%USERPROFILE%\.gabs-remote\keystore.properties` ou do caminho na variável `GABS_KEYSTORE_PROPS`. `keystore.properties` está no `.gitignore` do principal e do submódulo `android/`.

### Como criar (o Gab digita as senhas)

```powershell
mkdir $env:USERPROFILE\.gabs-remote
keytool -genkeypair -v -keystore $env:USERPROFILE\.gabs-remote\gabs-remote-release.jks -alias gabs-remote -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Gabs Remote, O=Gab Tavares, C=BR"
```

## Chave Ed25519 do manifesto (fase 4)

A chave que assina o `manifest.json` de cada Release (decisão 0006). Os updaters do host e do app só aceitam um manifesto assinado por ela. **Perder a chave** = host e app param de aceitar versões novas; vira reinstalar os dois à mão com uma chave nova embutida.

| Cópia | Onde | O que tem |
|---|---|---|
| **Original** | `%USERPROFILE%\.gabs-remote\` | `manifesto-ed25519.pem` (PKCS#8 cifrado, AES-256-CBC) e `manifesto-ed25519.pub.der` (só a pública) |
| **Backup 1, nuvem** | Google Drive do Gab, pasta `Gabs Remote/segredos/` | `gabs-remote-segredos.7z` refeito com a keystore **e** a chave juntas |
| **Backup 2, offline** | pendrive guardado em casa | o mesmo `gabs-remote-segredos.7z` |
| **Senha** | gerenciador de senhas do Gab, item "Gabs Remote — chave do manifesto" | senha da chave |

- Criada em 09/11/2026 pelo Gab (`openssl genpkey -algorithm ed25519 -aes-256-cbc`, OpenSSL do Git for Windows).
- **Chave pública** (base64 dos 32 bytes crus; é a que vai embutida no host, `update_key.h`, e no app, `UpdateKey.java`): `vt/Fsd5CTf97gakAjSs4U3ugaDp5pM2hBkNKlA+RibA=`
- SHA-256 do arquivo `manifesto-ed25519.pem`: `E723D75C52540566BD6A75C2FC851E131D8943411F365AE3414C124CFFE14CC4`
- Backups no Drive e no pendrive (`.7z` novo com `gabs-remote-release.jks`, `keystore.properties`, `manifesto-ed25519.pem`): **pendente** (o Gab refaz o `.7z` e troca os dois).
- Teste do backup: **pendente**, junto do da keystore (Task 11 da fase 4): baixar o `.7z`, extrair numa pasta temporária, `Get-FileHash` dos dois arquivos contra os SHA-256 deste arquivo, apagar a pasta e anotar a data.

### Como tirar a pública de novo (pede a senha)

```powershell
& 'C:\Program Files\Git\usr\bin\openssl.exe' pkey -in $env:USERPROFILE\.gabs-remote\manifesto-ed25519.pem -pubout -outform DER -out $env:USERPROFILE\.gabs-remote\manifesto-ed25519.pub.der
```

Os últimos 32 bytes do `.der` em base64 são a chave pública (`Get-ChavePublica` em `tools/release/Release.psm1` faz isso).
