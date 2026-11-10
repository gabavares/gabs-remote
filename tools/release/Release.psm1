# Ferramenta de release do Gabs Remote (plano da fase 4, Tasks 2 e 3; decisão 0006).
# Versão única no versao.json, manifesto da Release e assinatura Ed25519 pelo OpenSSL.
# Formato do manifesto: docs/superpowers/plans/2026-11-09-fase-4-atualizacao-e-ci.md.

Set-StrictMode -Version 3

$script:RaizRepo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$script:PadraoVersao = '^\d{1,3}\.\d{1,3}\.\d{1,3}$'
$script:PadraoArquivo = '^[A-Za-z0-9._-]+$'
$script:PadraoSha256 = '^[0-9a-f]{64}$'
# Prefixo DER do SubjectPublicKeyInfo de uma chave Ed25519 (RFC 8410); depois vêm os 32 bytes.
$script:PrefixoSpkiEd25519 = [byte[]](0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00)

function Get-OpenSsl {
    $candidatos = @('C:\Program Files\Git\usr\bin\openssl.exe')
    $cmd = Get-Command openssl -ErrorAction SilentlyContinue
    if ($cmd) { $candidatos += $cmd.Source }
    foreach ($c in $candidatos) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    throw 'OpenSSL não encontrado. Instale o Git for Windows (traz C:\Program Files\Git\usr\bin\openssl.exe).'
}

function Test-VersaoTexto([string]$Texto) {
    return ($null -ne $Texto) -and ($Texto -cmatch $script:PadraoVersao)
}

function Get-VersaoGabs {
    [CmdletBinding()]
    param([string]$Arquivo)
    if (-not $Arquivo) { $Arquivo = Join-Path $script:RaizRepo 'versao.json' }
    $obj = [IO.File]::ReadAllText($Arquivo) | ConvertFrom-Json
    foreach ($campo in 'version', 'minApp', 'minHost') {
        $valor = $obj.$campo
        if (-not (Test-VersaoTexto $valor)) { throw "versao.json: '$campo' inválido ('$valor'); use x.y.z (0 a 999 cada)." }
    }
    [pscustomobject]@{ Version = $obj.version; MinApp = $obj.minApp; MinHost = $obj.minHost }
}

function Get-VersionCode {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Versao)
    if (-not (Test-VersaoTexto $Versao)) { throw "Versão inválida: '$Versao'." }
    $p = $Versao.Split('.') | ForEach-Object { [int]$_ }
    [int]($p[0] * 1000000 + $p[1] * 1000 + $p[2])
}

function ConvertTo-JsonTexto([string]$Texto) {
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $Texto.ToCharArray()) {
        switch ([int]$ch) {
            0x22 { [void]$sb.Append('\"'); continue }
            0x5c { [void]$sb.Append('\\'); continue }
            0x0a { [void]$sb.Append('\n'); continue }
            0x0d { [void]$sb.Append('\r'); continue }
            0x09 { [void]$sb.Append('\t'); continue }
            default {
                if ([int]$ch -lt 0x20) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) }
            }
        }
    }
    [void]$sb.Append('"')
    $sb.ToString()
}

function Get-Sha256Arquivo([string]$Caminho) {
    (Get-FileHash -LiteralPath $Caminho -Algorithm SHA256).Hash.ToLowerInvariant()
}

function New-Manifesto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Versao,
        [Parameter(Mandatory)][string]$Data,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Notas,
        [Parameter(Mandatory)][string]$Instalador,
        [Parameter(Mandatory)][string]$Apk,
        [Parameter(Mandatory)][string]$MinApp,
        [Parameter(Mandatory)][string]$MinHost
    )
    foreach ($v in $Versao, $MinApp, $MinHost) { if (-not (Test-VersaoTexto $v)) { throw "Versão inválida: '$v'." } }
    if ($Data -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "Data inválida: '$Data' (use aaaa-mm-dd)." }
    $notasLf = $Notas.Replace("`r`n", "`n")
    $linhas = @(
        '{',
        '  "schema": 1,',
        ('  "version": ' + (ConvertTo-JsonTexto $Versao) + ','),
        ('  "date": ' + (ConvertTo-JsonTexto $Data) + ','),
        ('  "notes": ' + (ConvertTo-JsonTexto $notasLf) + ','),
        ('  "host": { "file": ' + (ConvertTo-JsonTexto "GabsRemote-Setup-$Versao.exe") +
            ', "sha256": "' + (Get-Sha256Arquivo $Instalador) + '", "size": ' + (Get-Item -LiteralPath $Instalador).Length +
            ', "minApp": ' + (ConvertTo-JsonTexto $MinApp) + ' },'),
        ('  "app": { "file": ' + (ConvertTo-JsonTexto "GabsRemote-$Versao.apk") +
            ', "sha256": "' + (Get-Sha256Arquivo $Apk) + '", "size": ' + (Get-Item -LiteralPath $Apk).Length +
            ', "versionCode": ' + (Get-VersionCode -Versao $Versao) + ', "minHost": ' + (ConvertTo-JsonTexto $MinHost) + ' }'),
        '}'
    )
    ($linhas -join "`n") + "`n"
}

function Test-Artefato($Artefato) {
    if ($null -eq $Artefato) { return $false }
    $file = $Artefato.file; $sha = $Artefato.sha256; $size = $Artefato.size
    if (-not ($file -is [string]) -or $file -cnotmatch $script:PadraoArquivo -or $file.Contains('..')) { return $false }
    if (-not ($sha -is [string]) -or $sha -cnotmatch $script:PadraoSha256) { return $false }
    if (-not ($size -is [int] -or $size -is [long]) -or $size -le 0) { return $false }
    return $true
}

function Test-Manifesto {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Json)
    try { $m = $Json | ConvertFrom-Json -ErrorAction Stop } catch { return $false }
    try {
        if ($m.schema -isnot [int] -or $m.schema -ne 1) { return $false }
        if (-not (Test-VersaoTexto $m.version)) { return $false }
        if (-not ($m.date -is [string])) { return $false }
        if (-not ($m.notes -is [string])) { return $false }
        if (-not (Test-Artefato $m.host) -or -not (Test-Artefato $m.app)) { return $false }
        if (-not (Test-VersaoTexto $m.host.minApp) -or -not (Test-VersaoTexto $m.app.minHost)) { return $false }
        if ($m.app.versionCode -isnot [int] -or $m.app.versionCode -ne (Get-VersionCode -Versao $m.version)) { return $false }
        return $true
    }
    catch { return $false }
}

function Invoke-AssinarManifesto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Manifesto,
        [Parameter(Mandatory)][string]$Chave,
        [string]$Saida = "$Manifesto.sig"
    )
    $openssl = Get-OpenSsl
    # Com a chave de produção, o OpenSSL pede a senha no terminal (o Gab digita).
    & $openssl pkeyutl -sign -inkey $Chave -rawin -in $Manifesto -out $Saida
    if ($LASTEXITCODE -ne 0) { throw "openssl pkeyutl -sign falhou (código $LASTEXITCODE)." }
    if ((Get-Item -LiteralPath $Saida).Length -ne 64) { throw 'A assinatura não tem 64 bytes: a chave é Ed25519?' }
}

function Test-AssinaturaManifesto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Manifesto,
        [Parameter(Mandatory)][string]$Assinatura,
        [Parameter(Mandatory)][string]$ChavePublicaBase64
    )
    $bruta = [Convert]::FromBase64String($ChavePublicaBase64.Trim())
    if ($bruta.Length -ne 32) { throw 'A chave pública precisa ter 32 bytes.' }
    if ((Get-Item -LiteralPath $Assinatura).Length -ne 64) { return $false }
    $der = Join-Path ([IO.Path]::GetTempPath()) ('gabs-pub-' + [guid]::NewGuid().ToString('N') + '.der')
    try {
        [IO.File]::WriteAllBytes($der, [byte[]]($script:PrefixoSpkiEd25519 + $bruta))
        $openssl = Get-OpenSsl
        $null = & $openssl pkeyutl -verify -pubin -inkey $der -keyform DER -rawin -in $Manifesto -sigfile $Assinatura 2>&1
        return ($LASTEXITCODE -eq 0)
    }
    finally { Remove-Item -LiteralPath $der -Force -ErrorAction SilentlyContinue }
}

function Get-ChavePublica {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Chave)
    $der = Join-Path ([IO.Path]::GetTempPath()) ('gabs-pub-' + [guid]::NewGuid().ToString('N') + '.der')
    try {
        $openssl = Get-OpenSsl
        & $openssl pkey -in $Chave -pubout -outform DER -out $der
        if ($LASTEXITCODE -ne 0) { throw "openssl pkey falhou (código $LASTEXITCODE)." }
        $bytes = [IO.File]::ReadAllBytes($der)
        if ($bytes.Length -ne 44) { throw 'A chave não é Ed25519.' }
        [Convert]::ToBase64String($bytes, 12, 32)
    }
    finally { Remove-Item -LiteralPath $der -Force -ErrorAction SilentlyContinue }
}

Export-ModuleMember -Function Get-OpenSsl, Get-VersaoGabs, Get-VersionCode, New-Manifesto, Test-Manifesto,
    Invoke-AssinarManifesto, Test-AssinaturaManifesto, Get-ChavePublica
