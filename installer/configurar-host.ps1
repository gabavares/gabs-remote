<#
.SYNOPSIS
    Configura o host do Gabs Remote já copiado para a pasta de instalação: serviço, firewall,
    pasta de atualizações e tela virtual. Chamado pelo instalador (gabs-remote.nsi) e pelo
    tools\setup\instalar-host.ps1. Decisões 0005 e 0006.
.DESCRIPTION
    Instalação (padrão) e -Atualizacao:
      1. cria <Pasta>\config\updates só com SYSTEM e Administradores (dono Administradores, sem herança);
      2. cria o serviço GabsRemote (scripts\install-service.bat), com início automático
         (scripts\autostart-service.bat) e reinício em falha (sc.exe failure);
      3. troca as regras de firewall "Gabs Remote*" pelas de Get-RegrasFirewall (só LAN e Tailscale);
      4. instala o driver SudoVDA (drivers\sudovda\install.bat) se o dispositivo não existir,
         nunca com -Atualizacao;
      5. inicia o serviço.
    -Desinstalar para e remove o serviço e as regras. -Parar só para o serviço e o sunshine.exe
    da pasta (o instalador usa antes de copiar os arquivos). A pasta config nunca é tocada.
    Precisa de administrador. Sai com código diferente de 0 em qualquer falha.
    Carregado com ". .\configurar-host.ps1", só define as funções (os testes Pester fazem isso).
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File configurar-host.ps1 -Pasta "C:\Program Files\Gabs Remote"
#>
[CmdletBinding()]
param(
    [string]$Pasta,
    [switch]$Atualizacao,
    [switch]$Desinstalar,
    [switch]$Parar
)

$NomeServico = 'GabsRemote'

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

function New-AclPastaUpdates {
    <# ACL de config\updates: só SYSTEM e Administradores gravam ali o instalador baixado. #>
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $admins = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
    $system = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'
    $acl.SetOwner($admins)
    foreach ($sid in $system, $admins) {
        $regra = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl',
            'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($regra)
    }
    $acl
}

function Set-AclPastaUpdates {
    param([Parameter(Mandatory)][string]$Pasta)
    Set-Acl -LiteralPath $Pasta -AclObject (New-AclPastaUpdates)
}

function Invoke-Bat {
    param([Parameter(Mandatory)][string]$Arquivo)
    Write-Host ">> $Arquivo"
    cmd.exe /c "`"$Arquivo`" < nul"
    if ($LASTEXITCODE -ne 0) { throw "$Arquivo falhou (código $LASTEXITCODE)." }
}

function Invoke-ScRecuperacao {
    & sc.exe @(Get-ArgumentosRecuperacao) | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sc.exe failure falhou (código $LASTEXITCODE)." }
}

function Stop-Servico {
    $svc = Get-Service -Name $NomeServico -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -ne 'Stopped') {
        Write-Host "Parando o serviço $NomeServico..."
        Stop-Service -Name $NomeServico -Force
        $svc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
    }
}

function Stop-HostDaPasta {
    <# Encerra o sunshine.exe desta instalação (o instalador precisa trocar o executável). #>
    param([Parameter(Mandatory)][string]$Pasta)
    if (-not (Test-Path -LiteralPath $Pasta)) { return }  # primeira instalação
    $raiz = (Resolve-Path -LiteralPath $Pasta).Path.TrimEnd([char]92) + [char]92
    Get-Process -Name sunshine, sunshinesvc -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and $_.Path.StartsWith($raiz, [StringComparison]::OrdinalIgnoreCase) } |
        Stop-Process -Force
}

function Start-Servico {
    $svc = Get-Service -Name $NomeServico
    if ($svc.Status -ne 'Running') { Start-Service -Name $NomeServico }
}

function Remove-Servico {
    param([Parameter(Mandatory)][string]$Pasta)
    $bat = Join-Path $Pasta 'scripts\uninstall-service.bat'
    if (Test-Path -LiteralPath $bat) { Invoke-Bat $bat } else { sc.exe delete $NomeServico | Out-Null }
}

function Remove-Regras {
    Get-NetFirewallRule -DisplayName 'Gabs Remote*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

function Add-Regras {
    foreach ($r in Get-RegrasFirewall) {
        New-NetFirewallRule -DisplayName $r.Nome -Direction Inbound -Action Allow -Profile $r.Perfil `
            -Protocol $r.Protocolo -LocalPort $r.Portas -RemoteAddress $r.EnderecoRemoto | Out-Null
        Write-Host "  regra: $($r.Nome) $($r.Protocolo) $($r.Portas -join ', ') (perfil $($r.Perfil), origem $($r.EnderecoRemoto -join ', '))"
    }
}

function Test-DispositivoSudoVda {
    <# Verdadeiro se o Windows já tem o dispositivo da tela virtual (pnputil). #>
    $saida = & pnputil.exe /enum-devices /class Display /ids 2>$null | Out-String
    return ($saida -match '(?i)root\\sudomaker\\sudovda')
}

function Invoke-ConfigurarHost {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Pasta,
        [switch]$Atualizacao,
        [switch]$Desinstalar,
        [switch]$Parar
    )
    if ($Parar) {
        # Antes de copiar os arquivos novos: o instalador chama com -Parar.
        Stop-Servico
        Stop-HostDaPasta -Pasta $Pasta
        return
    }
    if ($Desinstalar) {
        Stop-Servico
        Remove-Servico -Pasta $Pasta
        Remove-Regras
        Write-Host "OK: serviço e regras removidos. A configuração continua em $Pasta\config."
        return
    }

    # 1. Pasta das atualizações baixadas, só para SYSTEM e Administradores.
    $updates = Join-Path $Pasta 'config\updates'
    New-Item -ItemType Directory -Force -Path $updates | Out-Null
    Set-AclPastaUpdates -Pasta $updates

    # 2. Serviço, início automático e recuperação.
    Stop-Servico
    Invoke-Bat (Join-Path $Pasta 'scripts\install-service.bat')
    Invoke-Bat (Join-Path $Pasta 'scripts\autostart-service.bat')
    Invoke-ScRecuperacao

    # 3. Firewall: só LAN e Tailscale (decisão 0005).
    Remove-Regras
    Add-Regras

    # 4. Tela virtual: só na instalação, e só se o dispositivo não existir.
    if (-not $Atualizacao -and -not (Test-DispositivoSudoVda)) {
        Invoke-Bat (Join-Path $Pasta 'drivers\sudovda\install.bat')
    }

    # 5. Inicia.
    Start-Servico
    Write-Host "OK: Gabs Remote configurado em $Pasta. Painel: https://localhost:47990"
}

# Carregado com ". .\configurar-host.ps1": só define as funções.
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'ERRO: rode como administrador.' -ForegroundColor Red
    exit 1
}
if (-not $Pasta) { $Pasta = $PSScriptRoot }
# Log para diagnosticar a atualização silenciosa (sem janela): %TEMP% de quem roda (SYSTEM: C:\Windows\Temp).
try { Start-Transcript -Path (Join-Path $env:TEMP 'gabs-remote-configurar.log') -Append | Out-Null } catch {}
try {
    Invoke-ConfigurarHost -Pasta $Pasta -Atualizacao:$Atualizacao -Desinstalar:$Desinstalar -Parar:$Parar
    exit 0
}
catch {
    Write-Host "ERRO: $_" -ForegroundColor Red
    exit 1
}
