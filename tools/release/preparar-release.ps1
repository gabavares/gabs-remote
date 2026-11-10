<#
.SYNOPSIS
    Assina o APK e o manifesto de uma Release do Gabs Remote, no PC do Gab (decisão 0006).
.DESCRIPTION
    O CI (release.yml) cria o rascunho da Release com GabsRemote-Setup-<v>.exe e
    GabsRemote-<v>-unsigned.apk. Este script:
      1. confere que versao.json diz <v> e que existe docs\notas\<v>.md;
      2. baixa os dois arquivos do rascunho (gh release download);
      3. alinha (zipalign) e assina o APK com a keystore do Gab (keystore.properties);
      4. confere o certificado contra a impressão SHA-256 conhecida e o pacote/versionCode;
      5. monta o manifest.json, assina com a chave Ed25519 (o OpenSSL pede a senha) e confere
         com a chave pública de docs\segredos.md;
      6. mostra o resumo.
    Com -Enviar, também sobe o APK assinado, o manifest.json e o manifest.json.sig para o
    rascunho, apaga o APK sem assinatura e mostra o link para publicar.
.EXAMPLE
    powershell -File C:\gr\tools\release\preparar-release.ps1 -Versao 0.4.0
.EXAMPLE
    powershell -File C:\gr\tools\release\preparar-release.ps1 -Versao 0.4.0 -Enviar
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Versao,
    [switch]$Enviar,
    [string]$Repositorio = 'gabavares/gabs-remote',
    [string]$Chave,
    [string]$KeystoreProps
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Release.psm1') -Force

$ImpressaoCertificado = '170F8C182DA284C1012F35425E4045FFC7AD4EC6C98F485BFF949A7C8F267F49'
$PacoteApp = 'com.gabtavares.gabsremote'
$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Chave) { $Chave = Join-Path $env:USERPROFILE '.gabs-remote\manifesto-ed25519.pem' }
if (-not $KeystoreProps) {
    $KeystoreProps = if ($env:GABS_KEYSTORE_PROPS) { $env:GABS_KEYSTORE_PROPS } else { Join-Path $env:USERPROFILE '.gabs-remote\keystore.properties' }
}

function Parar([string]$Mensagem, [int]$Codigo = 1) {
    Write-Host "ERRO: $Mensagem" -ForegroundColor Red
    exit $Codigo
}

function Invoke-Exe([string]$Exe, [string[]]$Argumentos, [string]$Descricao) {
    & $Exe @Argumentos
    if ($LASTEXITCODE -ne 0) { Parar "$Descricao falhou (código $LASTEXITCODE)." }
}

# 1. Versão e notas
$v = Get-VersaoGabs
if ($v.Version -ne $Versao) { Parar "versao.json diz $($v.Version), não $Versao." }
$notasArq = Join-Path $raiz "docs\notas\$Versao.md"
if (-not (Test-Path -LiteralPath $notasArq)) { Parar "Faltam as notas em docs\notas\$Versao.md." }
$notas = [IO.File]::ReadAllText($notasArq, [Text.Encoding]::UTF8).Trim()
foreach ($arq in $Chave, $KeystoreProps) { if (-not (Test-Path -LiteralPath $arq)) { Parar "Não achei $arq (veja docs\segredos.md)." } }

$segredos = [IO.File]::ReadAllText((Join-Path $raiz 'docs\segredos.md'), [Text.Encoding]::UTF8)
$m = [regex]::Match($segredos, '\*\*Chave pública\*\*[^\r\n]*?`([A-Za-z0-9+/]{43}=)`')
if (-not $m.Success) { Parar 'Não achei a chave pública do manifesto em docs\segredos.md.' }
$publica = $m.Groups[1].Value

$androidHome = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User') }
if (-not $androidHome) { Parar 'ANDROID_HOME não definido (veja docs\ambiente.md).' }
$buildTools = Get-ChildItem (Join-Path $androidHome 'build-tools') -Directory |
    Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } -Descending | Select-Object -First 1
if (-not $buildTools) { Parar 'Android SDK sem build-tools.' }
$zipalign = Join-Path $buildTools.FullName 'zipalign.exe'
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'
$aapt2 = Join-Path $buildTools.FullName 'aapt2.exe'

$tag = "v$Versao"
$pasta = Join-Path ([IO.Path]::GetTempPath()) "gabs-release-$Versao"
if (Test-Path -LiteralPath $pasta) { Remove-Item -LiteralPath $pasta -Recurse -Force }
New-Item -ItemType Directory -Path $pasta | Out-Null

# 2. Arquivos do rascunho
$nomeExe = "GabsRemote-Setup-$Versao.exe"
$nomeUnsigned = "GabsRemote-$Versao-unsigned.apk"
$nomeApk = "GabsRemote-$Versao.apk"

# Origem: só assina o que o CI gerou a partir da tag que está neste PC (revisão final da fase 4).
function Get-Rascunho {
    $json = & gh api "repos/$Repositorio/releases?per_page=30"
    if ($LASTEXITCODE -ne 0) { Parar 'gh api releases falhou.' }
    $r = @($json | ConvertFrom-Json) | Where-Object { $_.tag_name -eq $tag } | Select-Object -First 1
    if (-not $r) { Parar "Não achei a Release $tag (o workflow Release já terminou?)." }
    [pscustomobject]@{ isDraft = [bool]$r.draft; assets = @($r.assets) }
}
$problemas = @(Test-OrigemRascunho -Release (Get-Rascunho) -Arquivos @($nomeExe, $nomeUnsigned))
if ($problemas.Count -gt 0) { Parar ("Rascunho recusado: " + ($problemas -join ' ')) }
$commitLocal = (& git -C $raiz rev-parse "$tag^{commit}" 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $commitLocal) { Parar "A tag $tag não existe neste PC (git fetch --tags)." }
$commitRemoto = (& gh api "repos/$Repositorio/commits/$tag" --jq .sha)
if ($commitRemoto -ne $commitLocal) { Parar "A tag $tag no GitHub ($commitRemoto) não é a deste PC ($commitLocal)." }
$runs = & gh run list --repo $Repositorio --workflow release.yml --limit 20 --json headSha,conclusion,status | ConvertFrom-Json
if (-not (@($runs) | Where-Object { $_.headSha -eq $commitLocal -and $_.conclusion -eq 'success' })) {
    Parar "Não achei um workflow Release concluído com sucesso no commit $commitLocal."
}
Write-Host "Origem conferida: rascunho do CI, commit $commitLocal (tag $tag igual à local)." -ForegroundColor Green

Write-Host ">> Baixando $tag de $Repositorio" -ForegroundColor Cyan
Invoke-Exe 'gh' @('release', 'download', $tag, '--repo', $Repositorio, '--dir', $pasta, '--pattern', $nomeExe, '--pattern', $nomeUnsigned) 'gh release download'
$exe = Join-Path $pasta $nomeExe
$unsigned = Join-Path $pasta $nomeUnsigned
foreach ($arq in $exe, $unsigned) { if (-not (Test-Path -LiteralPath $arq)) { Parar "O rascunho $tag não tem $(Split-Path $arq -Leaf)." } }

# 3. Alinhar e assinar o APK (as senhas vêm do keystore.properties, por variável do processo)
$props = @{}
foreach ($linha in [IO.File]::ReadAllLines($KeystoreProps)) {
    if ($linha -match '^\s*([^#=]+?)\s*=\s*(.*)$') { $props[$Matches[1]] = $Matches[2] }
}
$ks = $props['storeFile']
if (-not [IO.Path]::IsPathRooted($ks)) { $ks = Join-Path (Split-Path $KeystoreProps -Parent) $ks }
$alinhado = Join-Path $pasta 'alinhado.apk'
$apk = Join-Path $pasta $nomeApk
Invoke-Exe $zipalign @('-p', '-f', '4', $unsigned, $alinhado) 'zipalign'
try {
    $env:GABS_KS_PASS = $props['storePassword']
    $env:GABS_KEY_PASS = $props['keyPassword']
    Invoke-Exe $apksigner @('sign', '--ks', $ks, '--ks-key-alias', $props['keyAlias'], '--ks-pass', 'env:GABS_KS_PASS',
        '--key-pass', 'env:GABS_KEY_PASS', '--out', $apk, $alinhado) 'apksigner sign'
}
finally {
    Remove-Item env:GABS_KS_PASS, env:GABS_KEY_PASS -ErrorAction SilentlyContinue
    $props = $null
}
Remove-Item -LiteralPath $alinhado, "$apk.idsig" -Force -ErrorAction SilentlyContinue

# 4. Conferir certificado, pacote e versionCode
$certs = & $apksigner verify --print-certs $apk
if ($LASTEXITCODE -ne 0) { Parar 'apksigner verify falhou.' }
# "Signer #1 certificate SHA-256 digest: ..." (apksigner antigo) ou "V2 Signer: certificate SHA-256 digest: ..." (37+):
# todo certificado listado precisa ser o do Gab, e precisa haver ao menos um.
$impressoes = @($certs | ForEach-Object {
    if ($_ -match 'certificate SHA-256 digest:\s*([0-9a-fA-F:]+)') { $Matches[1].Replace(':', '').ToUpperInvariant() }
} | Sort-Object -Unique)
if ($impressoes.Count -ne 1 -or $impressoes[0] -ne $ImpressaoCertificado) {
    Parar "O APK foi assinado com outro certificado ($($impressoes -join ', ')). Pare e confira a keystore."
}
$badging = (& $aapt2 dump badging $apk) | Select-Object -First 1
$codigoEsperado = Get-VersionCode -Versao $Versao
if ($badging -notmatch "name='$([regex]::Escape($PacoteApp))'" -or $badging -notmatch "versionCode='$codigoEsperado'" -or $badging -notmatch "versionName='$([regex]::Escape($Versao))'") {
    Parar "O APK não é $PacoteApp $Versao ($codigoEsperado): $badging"
}

# 5. Manifesto
$json = New-Manifesto -Versao $Versao -Data (Get-Date -Format 'yyyy-MM-dd') -Notas $notas -Instalador $exe -Apk $apk -MinApp $v.MinApp -MinHost $v.MinHost
if (-not (Test-Manifesto -Json $json)) { Parar 'O manifesto gerado não passou na validação.' }
$manifesto = Join-Path $pasta 'manifest.json'
[IO.File]::WriteAllText($manifesto, $json, (New-Object Text.UTF8Encoding $false))
Write-Host '>> Assinando o manifesto: digite a senha da chave do manifesto.' -ForegroundColor Cyan
Invoke-AssinarManifesto -Manifesto $manifesto -Chave $Chave
if (-not (Test-AssinaturaManifesto -Manifesto $manifesto -Assinatura "$manifesto.sig" -ChavePublicaBase64 $publica)) {
    Parar 'A assinatura do manifesto não confere com a chave pública de docs\segredos.md.'
}

# 6. Resumo
$obj = $json | ConvertFrom-Json
Write-Host ''
Write-Host "Gabs Remote $Versao — pronto em $pasta" -ForegroundColor Green
Write-Host ("  Instalador  {0}  {1:N0} bytes  {2}" -f $obj.host.file, $obj.host.size, $obj.host.sha256)
Write-Host ("  APK         {0}  {1:N0} bytes  {2}" -f $obj.app.file, $obj.app.size, $obj.app.sha256)
Write-Host "  versionCode $($obj.app.versionCode) · minApp $($obj.host.minApp) · minHost $($obj.app.minHost)"
Write-Host "  Certificado do APK confere; assinatura do manifesto confere."

if (-not $Enviar) {
    Write-Host ''
    Write-Host "Confira o resumo e rode de novo com -Enviar para subir ao rascunho $tag." -ForegroundColor Yellow
    exit 0
}

$problemas = @(Test-OrigemRascunho -Release (Get-Rascunho) -Arquivos @($nomeExe, $nomeUnsigned))
if ($problemas.Count -gt 0) { Parar ("Rascunho mudou desde a conferência: " + ($problemas -join ' ')) }
Write-Host ">> Enviando para o rascunho $tag" -ForegroundColor Cyan
Invoke-Exe 'gh' @('release', 'upload', $tag, '--repo', $Repositorio, '--clobber', $apk, $manifesto, "$manifesto.sig") 'gh release upload'
Invoke-Exe 'gh' @('release', 'delete-asset', $tag, $nomeUnsigned, '--repo', $Repositorio, '-y') 'gh release delete-asset'
$url = & gh release view $tag --repo $Repositorio --json url --jq .url
Write-Host "OK: rascunho completo. Para publicar: gh release edit $tag --repo $Repositorio --draft=false" -ForegroundColor Green
Write-Host "    $url"
exit 0
