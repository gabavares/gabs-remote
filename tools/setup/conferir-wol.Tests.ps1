# Testes Pester do conferir-wol.ps1 (Task 2 do plano da fase 3).
# Rodar: Invoke-Pester C:\gr\tools\setup\conferir-wol.Tests.ps1

BeforeAll {
    . (Join-Path $PSScriptRoot 'conferir-wol.ps1')
}

Describe 'Get-EstadoWol' {
    BeforeEach {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'Ethernet'; InterfaceDescription = 'Realtek PCIe GbE Family Controller'; Status = 'Up' } }
        Mock Get-PlacasArmadas { @('Realtek PCIe GbE Family Controller') }
    }

    It 'pacote mágico ativo e placa armada: WoL ativo' {
        Mock Get-NetAdapterAdvancedProperty { [pscustomobject]@{ RegistryKeyword = '*WakeOnMagicPacket'; RegistryValue = @('1') } }
        $e = @(Get-EstadoWol)
        $e.Count | Should -Be 1
        $e[0].Ativo | Should -BeTrue
        $e[0].Mensagem | Should -Be 'WoL ativo na placa Ethernet (Realtek PCIe GbE Family Controller).'
    }

    It 'pacote mágico desativado: orienta ativar no Gerenciador de Dispositivos' {
        Mock Get-NetAdapterAdvancedProperty { [pscustomobject]@{ RegistryKeyword = '*WakeOnMagicPacket'; RegistryValue = @('0') } }
        $e = @(Get-EstadoWol)
        $e[0].Ativo | Should -BeFalse
        $e[0].Mensagem | Should -Match 'Gerenciador de Dispositivos'
        $e[0].Mensagem | Should -Match 'Pacote Wake on Magic'
    }

    It 'placa não armada para acordar o PC: orienta a aba Gerenciamento de Energia' {
        Mock Get-NetAdapterAdvancedProperty { [pscustomobject]@{ RegistryKeyword = '*WakeOnMagicPacket'; RegistryValue = @('1') } }
        Mock Get-PlacasArmadas { @() }
        $e = @(Get-EstadoWol)
        $e[0].Ativo | Should -BeFalse
        $e[0].Mensagem | Should -Match 'Gerenciamento de Energia'
    }
}

Describe 'Get-InicioRapido' {
    It 'HiberbootEnabled = 1: avisa que o Início rápido pode impedir o WoL' {
        Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 1 } }
        $r = Get-InicioRapido
        $r.Ligado | Should -BeTrue
        $r.Mensagem | Should -Match 'Início rápido'
        $r.Mensagem | Should -Match 'pode impedir'
    }

    It 'HiberbootEnabled = 0: nada a ajustar' {
        Mock Get-ItemProperty { [pscustomobject]@{ HiberbootEnabled = 0 } }
        (Get-InicioRapido).Ligado | Should -BeFalse
    }
}
