<#
.SYNOPSIS
    Instala (ou desinstala) o host do Gabs Remote como serviço do Windows, com início automático,
    reinício em caso de falha e as regras de firewall de casa e do Tailscale.
.DESCRIPTION
    Precisa rodar como administrador (código 1 se não for) e pelo caminho sem espaço C:\gr
    (código 2 se não for). Passos da instalação:
      1. para o serviço GabsRemote, se existir;
      2. copia o build (host\build) para C:\Program Files\Gabs Remote com "cmake --install";
      3. na primeira instalação, copia host\build\config (pareamentos e login do painel);
      4. cria o serviço (scripts\install-service.bat) com início automático
         (scripts\autostart-service.bat) e reinício em falha (sc.exe failure);
      5. troca as regras "Gabs Remote (dev)*" pelas regras de Get-RegrasFirewall;
      6. inicia o serviço.
    -Desinstalar remove o serviço, as regras e os arquivos instalados, e mantém a pasta config.
    As funções Get-RegrasFirewall e Get-ArgumentosRecuperacao podem ser carregadas com
    ". .\instalar-host.ps1" sem instalar nada (os testes Pester fazem isso).
.EXAMPLE
    powershell -File C:\gr\tools\setup\instalar-host.ps1
.EXAMPLE
    powershell -File C:\gr\tools\setup\instalar-host.ps1 -Desinstalar
#>
[CmdletBinding()]
param(
    [switch]$Desinstalar
)

$NomeServico = 'GabsRemote'
$PastaInstalacao = 'C:\Program Files\Gabs Remote'

# Portas do host (as mesmas do Sunshine, mais 48100/UDP do relógio do medidor de latência).
$PortasTcp = 47984, 47989, 47990, 48010
$PortasUdp = 47998, 47999, 48000, 48002, 48010, 48100
$PortaPainel = 47990
$RedesTailscale = '100.64.0.0/10', 'fd7a:115c:a1e0::/48'

function Get-RegrasFirewall {
    <# Regras de entrada do host. O painel (47990) só abre na rede local (spec §5.4). #>
    $tcpTailscale = $PortasTcp | Where-Object { $_ -ne $PortaPainel }
    @(
        [pscustomobject]@{ Nome = 'Gabs Remote LAN TCP'; Protocolo = 'TCP'; Portas = $PortasTcp; Perfil = 'Private'; EnderecoRemoto = 'LocalSubnet' }
        [pscustomobject]@{ Nome = 'Gabs Remote LAN UDP'; Protocolo = 'UDP'; Portas = $PortasUdp; Perfil = 'Private'; EnderecoRemoto = 'LocalSubnet' }
        [pscustomobject]@{ Nome = 'Gabs Remote Tailscale TCP'; Protocolo = 'TCP'; Portas = $tcpTailscale; Perfil = 'Any'; EnderecoRemoto = $RedesTailscale }
        [pscustomobject]@{ Nome = 'Gabs Remote Tailscale UDP'; Protocolo = 'UDP'; Portas = $PortasUdp; Perfil = 'Any'; EnderecoRemoto = $RedesTailscale }
    )
}

function Get-ArgumentosRecuperacao {
    <# Argumentos do sc.exe: reinicia em 5 s, 5 s e 30 s; zera a contagem de falhas em 1 dia. #>
    @('failure', $NomeServico, 'reset=', '86400', 'actions=', 'restart/5000/restart/5000/restart/30000')
}

# Carregado com ". .\instalar-host.ps1": só define as funções.
if ($MyInvocation.InvocationName -eq '.') { return }

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

$hostDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'host'
$scripts = Join-Path $PastaInstalacao 'scripts'

function Invoke-Bat {
    param([string]$Arquivo)
    Write-Host ">> $Arquivo" -ForegroundColor Cyan
    cmd.exe /c "`"$Arquivo`" < nul"
}

function Stop-Servico {
    $svc = Get-Service -Name $NomeServico -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Write-Host "Parando o serviço $NomeServico..."
        Stop-Service -Name $NomeServico -Force
        $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }
}

function Remove-Regras {
    Get-NetFirewallRule -DisplayName 'Gabs Remote*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

if ($Desinstalar) {
    Stop-Servico
    $bat = Join-Path $scripts 'uninstall-service.bat'
    if (Test-Path -LiteralPath $bat) { Invoke-Bat $bat } else { sc.exe delete $NomeServico | Out-Null }
    Remove-Regras
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

# 3. Primeira instalação: leva a configuração do build (PCs pareados, login do painel).
$configDestino = Join-Path $PastaInstalacao 'config'
$configBuild = Join-Path $hostDir 'build\config'
if (-not (Test-Path -LiteralPath (Join-Path $configDestino 'sunshine_state.json')) -and (Test-Path -LiteralPath $configBuild)) {
    New-Item -ItemType Directory -Force -Path $configDestino | Out-Null
    Get-ChildItem -LiteralPath $configBuild -Force | Where-Object Name -notlike '*.log' |
        Copy-Item -Destination $configDestino -Recurse -Force
    Write-Host "OK: configuração do build copiada para $configDestino." -ForegroundColor Green
}

# 4. Serviço, início automático e recuperação.
Invoke-Bat (Join-Path $scripts 'install-service.bat')
Invoke-Bat (Join-Path $scripts 'autostart-service.bat')
& sc.exe @(Get-ArgumentosRecuperacao) | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: sc.exe failure falhou (código $LASTEXITCODE)." -ForegroundColor Red
    exit 5
}

# 5. Firewall.
Remove-Regras
foreach ($r in Get-RegrasFirewall) {
    New-NetFirewallRule -DisplayName $r.Nome -Direction Inbound -Action Allow -Profile $r.Perfil `
        -Protocol $r.Protocolo -LocalPort $r.Portas -RemoteAddress $r.EnderecoRemoto | Out-Null
    Write-Host "  regra: $($r.Nome) $($r.Protocolo) $($r.Portas -join ', ') (perfil $($r.Perfil), origem $($r.EnderecoRemoto -join ', '))"
}

# 6. Inicia.
$svc = Get-Service -Name $NomeServico
if ($svc.Status -ne 'Running') { Start-Service -Name $NomeServico }
Write-Host "OK: serviço $NomeServico instalado em $PastaInstalacao, com início automático. Painel: https://localhost:47990" -ForegroundColor Green
exit 0
