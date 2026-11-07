<#
.SYNOPSIS
    Libera no firewall do Windows as portas do host (Sunshine), só no perfil Privado.
.DESCRIPTION
    Precisa rodar como administrador. Cria (ou recria) duas regras de entrada chamadas
    "Gabs Remote (dev)": uma TCP e uma UDP. Para desfazer:
        Remove-NetFirewallRule -DisplayName 'Gabs Remote (dev)*'
    A rede de casa precisa estar como "Privada" nas configurações do Windows.
#>
$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'ERRO: rode este script como administrador.' -ForegroundColor Red
    exit 1
}

Get-NetFirewallRule -DisplayName 'Gabs Remote (dev)*' -ErrorAction SilentlyContinue | Remove-NetFirewallRule

New-NetFirewallRule -DisplayName 'Gabs Remote (dev) TCP' -Direction Inbound -Action Allow -Profile Private `
    -Protocol TCP -LocalPort 47984, 47989, 47990, 48010 | Out-Null
New-NetFirewallRule -DisplayName 'Gabs Remote (dev) UDP' -Direction Inbound -Action Allow -Profile Private `
    -Protocol UDP -LocalPort 47998, 47999, 48000, 48002, 48010 | Out-Null

Write-Host 'OK: regras criadas:' -ForegroundColor Green
Get-NetFirewallRule -DisplayName 'Gabs Remote (dev)*' | ForEach-Object {
    $p = $_ | Get-NetFirewallPortFilter
    "  $($_.DisplayName): $($p.Protocol) $($p.LocalPort -join ', ') (perfil $($_.Profile))"
}

$redes = Get-NetConnectionProfile
foreach ($r in $redes) {
    if ($r.NetworkCategory -ne 'Private') {
        Write-Host "ATENÇÃO: a rede '$($r.Name)' está como $($r.NetworkCategory). Mude para Privada, senão as regras não valem." -ForegroundColor Yellow
    } else {
        Write-Host "OK: a rede '$($r.Name)' está como Privada." -ForegroundColor Green
    }
}
