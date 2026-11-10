<#
.SYNOPSIS
    Gera o instalador do host: installer\out\GabsRemote-Setup-<versão>.exe (NSIS).
.DESCRIPTION
    Precisa do host já compilado (tools\build\build-host.ps1). Passos:
      1. cmake --install host\build --prefix installer\out\stage;
      2. copia drivers\sudovda e installer\configurar-host.ps1 para o stage;
      3. makensis (NSIS do MSYS2 UCRT64) com a versão do versao.json.
    Roda por C:\gr (caminho sem espaço). Sai com código diferente de 0 em qualquer falha.
.PARAMETER Msys2
    Pasta do MSYS2 (padrão C:\msys64; no CI, a saída do setup-msys2).
.EXAMPLE
    powershell -File C:\gr\tools\build\build-instalador.ps1
#>
[CmdletBinding()]
param(
    [string]$Msys2 = 'C:\msys64'
)
$ErrorActionPreference = 'Stop'

$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if ($raiz -match '\s') {
    Write-Host "ERRO: caminho com espaço ('$raiz'). Use: powershell -File C:\gr\tools\build\build-instalador.ps1" -ForegroundColor Red
    exit 2
}
$bash = Join-Path $Msys2 'usr\bin\bash.exe'
$makensis = Join-Path $Msys2 'ucrt64\bin\makensis.exe'
foreach ($exe in $bash, $makensis) {
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Host "ERRO: não achei $exe (MSYS2 com mingw-w64-ucrt-x86_64-nsis)." -ForegroundColor Red
        exit 3
    }
}
$hostBuild = Join-Path $raiz 'host\build'
if (-not (Test-Path -LiteralPath (Join-Path $hostBuild 'sunshine.exe'))) {
    Write-Host 'ERRO: host\build\sunshine.exe não existe. Rode antes o build-host.ps1.' -ForegroundColor Red
    exit 4
}

Import-Module (Join-Path $raiz 'tools\release\Release.psm1') -Force
$versao = (Get-VersaoGabs).Version

$out = Join-Path $raiz 'installer\out'
$stage = Join-Path $out 'stage'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$env:MSYSTEM = 'UCRT64'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'inherit'
$prefixo = $stage -replace '\\', '/'
$build = $hostBuild -replace '\\', '/'
Write-Host ">> cmake --install $build --prefix $prefixo" -ForegroundColor Cyan
& $bash -lc "cmake --install '$build' --prefix '$prefixo'"
if ($LASTEXITCODE -ne 0) { Write-Host "ERRO: cmake --install falhou ($LASTEXITCODE)." -ForegroundColor Red; exit 5 }

New-Item -ItemType Directory -Force -Path (Join-Path $stage 'drivers') | Out-Null
Copy-Item -LiteralPath (Join-Path $raiz 'drivers\sudovda') -Destination (Join-Path $stage 'drivers') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $raiz 'installer\configurar-host.ps1') -Destination $stage -Force

$exeSaida = Join-Path $out "GabsRemote-Setup-$versao.exe"
$icone = Join-Path $raiz 'host\src_assets\common\assets\web\public\images\gabs-remote.ico'
$nsi = Join-Path $raiz 'installer\gabs-remote.nsi'
Write-Host ">> makensis $versao" -ForegroundColor Cyan
& $makensis -V2 "-DVERSION=$versao" "-DSTAGE=$stage" "-DOUTFILE=$exeSaida" "-DICON=$icone" $nsi
if ($LASTEXITCODE -ne 0) { Write-Host "ERRO: makensis falhou ($LASTEXITCODE)." -ForegroundColor Red; exit 6 }

$tam = (Get-Item -LiteralPath $exeSaida).Length
Write-Host ("OK: {0} ({1:N1} MB)" -f $exeSaida, ($tam / 1MB)) -ForegroundColor Green
exit 0
