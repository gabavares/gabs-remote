# Testes Pester do instalar-host.ps1 (fase 2, Task 4; ajustado na fase 4, Task 6).
# As regras de firewall e a recuperação do serviço foram para installer\configurar-host.ps1
# (testes em installer\configurar-host.Tests.ps1).
# Rodar: Invoke-Pester C:\gr\tools\setup\instalar-host.Tests.ps1

BeforeAll {
    $script:texto = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'instalar-host.ps1') -Raw -Encoding UTF8
    $script:configurar = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'installer\configurar-host.ps1'
}

Describe 'instalar-host.ps1' {
    It 'usa o configurar-host.ps1 do instalador para serviço, firewall e SudoVDA' {
        Test-Path -LiteralPath $script:configurar | Should -BeTrue
        $script:texto | Should -Match ([regex]::Escape("installer\configurar-host.ps1"))
        $script:texto | Should -Match 'Invoke-ConfigurarHost -Pasta \$PastaInstalacao\s'
        $script:texto | Should -Match 'Invoke-ConfigurarHost -Pasta \$PastaInstalacao -Desinstalar'
    }

    It 'lê -Desinstalar antes de carregar o configurar-host.ps1 (o param dele sobrescreve a variável)' {
        $carga = $script:texto.IndexOf("installer\configurar-host.ps1')")
        $carga | Should -BeGreaterThan 0
        # Depois de carregar, o script não pode mais ler $Desinstalar.
        $script:texto.Substring($carga) | Should -Not -Match '\$Desinstalar\b'
    }

    It 'não cria regras de firewall por conta própria' {
        $script:texto | Should -Not -Match 'New-NetFirewallRule'
    }

    It 'na desinstalação mantém a pasta config' {
        $script:texto | Should -Match "Where-Object Name -ne 'config'"
    }
}
