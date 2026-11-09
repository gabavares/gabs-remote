<#
.SYNOPSIS
    Confere se o PC está pronto para ser ligado pela rede (Wake-on-LAN).
.DESCRIPTION
    Para cada placa de rede física ligada, confere a propriedade "Pacote Wake on Magic"
    (*WakeOnMagicPacket) e se a placa pode acordar o PC (powercfg /devicequery wake_armed).
    Confere também o "Início rápido" do Windows, que pode impedir o WoL com o PC desligado.
    Não muda nada: só mostra o que ajustar. Não precisa de administrador.
    O Get-NetAdapterPowerManagement falha na Realtek do PC do Gab ("dispositivo não está
    funcionando"), por isso o script lê a propriedade avançada e o powercfg.
    As funções podem ser carregadas com ". .\conferir-wol.ps1" sem rodar nada (os testes Pester fazem isso).
.EXAMPLE
    powershell -File C:\gr\tools\setup\conferir-wol.ps1
#>

function Get-PlacasArmadas {
    # Nomes dos dispositivos que podem acordar o PC.
    @(powercfg /devicequery wake_armed 2>$null | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
}

function Get-EstadoWol {
    $armadas = @(Get-PlacasArmadas)
    foreach ($placa in @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')) {
        $nome = "$($placa.Name) ($($placa.InterfaceDescription))"
        $prop = Get-NetAdapterAdvancedProperty -Name $placa.Name -RegistryKeyword '*WakeOnMagicPacket' -ErrorAction SilentlyContinue
        $magico = $prop -and (@($prop.RegistryValue) -contains '1')
        $armada = $armadas -contains $placa.InterfaceDescription
        if (-not $prop) {
            $msg = "A placa $nome não informa o Pacote Wake on Magic: confira no Gerenciador de Dispositivos, nas propriedades da placa, aba Avançado."
        } elseif (-not $magico) {
            $msg = "WoL desativado na placa ${nome}: no Gerenciador de Dispositivos, propriedades da placa, aba Avançado, ponha 'Pacote Wake on Magic' em Ativado."
        } elseif (-not $armada) {
            $msg = "A placa $nome não pode acordar o PC: no Gerenciador de Dispositivos, propriedades da placa, aba Gerenciamento de Energia, marque 'Permitir que este dispositivo ative o computador'."
        } else {
            $msg = "WoL ativo na placa $nome."
        }
        [pscustomobject]@{ Placa = $placa.Name; Ativo = [bool]($magico -and $armada); Mensagem = $msg }
    }
}

function Get-InicioRapido {
    $chave = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    $valor = (Get-ItemProperty -Path $chave -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    if ($valor -eq 1) {
        [pscustomobject]@{ Ligado = $true; Mensagem = 'O Início rápido do Windows está ligado e pode impedir o WoL com o PC desligado. Se o PC não ligar pela rede, desligue em Opções de Energia > Escolher a função dos botões de energia.' }
    } else {
        [pscustomobject]@{ Ligado = $false; Mensagem = 'Início rápido desligado.' }
    }
}

if ($MyInvocation.InvocationName -eq '.') { return }

$estados = @(Get-EstadoWol)
if ($estados.Count -eq 0) {
    Write-Host 'Nenhuma placa de rede física ligada.' -ForegroundColor Yellow
}
foreach ($e in $estados) {
    Write-Host $e.Mensagem -ForegroundColor $(if ($e.Ativo) { 'Green' } else { 'Yellow' })
}
$ir = Get-InicioRapido
Write-Host $ir.Mensagem -ForegroundColor $(if ($ir.Ligado) { 'Yellow' } else { 'Green' })
exit 0
