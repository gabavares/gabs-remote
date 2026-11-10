<#
.SYNOPSIS
    Instala (ou desinstala) o host do Gabs Remote a partir do build local, como serviço do Windows,
    com início automático, reinício em caso de falha e as regras de firewall de casa e do Tailscale.
.DESCRIPTION
    Precisa rodar como administrador (código 1 se não for) e pelo caminho sem espaço C:\gr
    (código 2 se não for). Passos da instalação:
      1. para o serviço GabsRemote, se existir;
      2. copia o build (host\build) para C:\Program Files\Gabs Remote com "cmake --install";
      3. na primeira instalação, copia host\build\config (pareamentos e login do painel);
      4. chama installer\configurar-host.ps1 (o mesmo passo do instalador da fase 4): pasta
         config\updates, serviço com início automático e recuperação, regras de firewall
         (só LAN e Tailscale), driver SudoVDA se faltar, e inicia o serviço.
    -Desinstalar remove o serviço, as regras e os arquivos instalados, e mantém a pasta config.
    Desde a fase 4 o caminho normal no PC do Gab é o instalador (GabsRemote-Setup-<versão>.exe);
    este script fica para testar um build local.
.EXAMPLE
    powershell -File C:\gr\tools\setup\instalar-host.ps1
.EXAMPLE
    powershell -File C:\gr\tools\setup\instalar-host.ps1 -Desinstalar
#>
[CmdletBinding()]
param(
    [switch]$Desinstalar
)

$PastaInstalacao = 'C:\Program Files\Gabs Remote'

$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'ERRO: rode este script como administrador.' -ForegroundColor Red
    exit 1
}
if ($PSScriptRoot -match '\s') {
    Write-Host "ERRO: caminho com espaço ('$PSScriptRoot'). Rode por C:\gr: powershell -File C:\gr\tools\setup\instalar-host.ps1" -ForegroundColor Red
    exit 2
}

$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$hostDir = Join-Path $raiz 'host'
# Serviço, firewall, config\updates e SudoVDA: as mesmas funções do instalador.
. (Join-Path $raiz 'installer\configurar-host.ps1')

if ($Desinstalar) {
    Invoke-ConfigurarHost -Pasta $PastaInstalacao -Desinstalar
    if (Test-Path -LiteralPath $PastaInstalacao) {
        Get-ChildItem -LiteralPath $PastaInstalacao -Force | Where-Object Name -ne 'config' |
            Remove-Item -Recurse -Force
    }
    Write-Host "OK: serviço, regras e arquivos removidos. A configuração continua em $PastaInstalacao\config." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path (Join-Path $hostDir 'build\sunshine.exe'))) {
    Write-Host 'ERRO: host\build\sunshine.exe não existe. Rode antes: powershell -File C:\gr\tools\build\build-host.ps1' -ForegroundColor Red
    exit 3
}

Stop-Servico
Get-Process -Name sunshine -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$PastaInstalacao\*" } | Stop-Process -Force

# 2. cmake --install pelo MSYS2 UCRT64, como o build-host.ps1.
$env:MSYSTEM = 'UCRT64'
$env:CHERE_INVOKING = '1'
$env:MSYS2_PATH_TYPE = 'inherit'
$destino = $PastaInstalacao -replace '\\', '/'
Push-Location $hostDir
try {
    Write-Host ">> cmake --install build --prefix '$destino'" -ForegroundColor Cyan
    & 'C:\msys64\usr\bin\bash.exe' -lc "cmake --install build --prefix '$destino'"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: cmake --install falhou (código $LASTEXITCODE)." -ForegroundColor Red
        exit 4
    }
} finally {
    Pop-Location
}
# O driver da tela virtual vai junto, como no instalador.
Copy-Item -LiteralPath (Join-Path $raiz 'drivers\sudovda') -Destination (Join-Path $PastaInstalacao 'drivers') -Recurse -Force

# 3. Primeira instalação: leva a configuração do build (PCs pareados, login do painel).
$configDestino = Join-Path $PastaInstalacao 'config'
$configBuild = Join-Path $hostDir 'build\config'
if (-not (Test-Path -LiteralPath (Join-Path $configDestino 'sunshine_state.json')) -and (Test-Path -LiteralPath $configBuild)) {
    New-Item -ItemType Directory -Force -Path $configDestino | Out-Null
    Get-ChildItem -LiteralPath $configBuild -Force | Where-Object Name -notlike '*.log' |
        Copy-Item -Destination $configDestino -Recurse -Force
    Write-Host "OK: configuração do build copiada para $configDestino." -ForegroundColor Green
}

# 4. Serviço, firewall, config\updates, SudoVDA e início.
try {
    Invoke-ConfigurarHost -Pasta $PastaInstalacao
} catch {
    Write-Host "ERRO: $_" -ForegroundColor Red
    exit 5
}
Write-Host "OK: serviço GabsRemote instalado em $PastaInstalacao, com início automático. Painel: https://localhost:47990" -ForegroundColor Green
exit 0
