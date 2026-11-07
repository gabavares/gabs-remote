# Testes Pester do instalar-host.ps1 (Task 4 do plano da fase 2).
# Rodar: Invoke-Pester C:\gr\tools\setup\instalar-host.Tests.ps1

BeforeAll {
    . (Join-Path $PSScriptRoot 'instalar-host.ps1')
}

Describe 'Get-RegrasFirewall' {
    BeforeAll { $script:regras = @(Get-RegrasFirewall) }

    It 'devolve as 4 regras com os nomes certos' {
        $script:regras.Count | Should -Be 4
        ($script:regras.Nome | Sort-Object) -join '|' | Should -Be (@(
            'Gabs Remote LAN TCP', 'Gabs Remote LAN UDP',
            'Gabs Remote Tailscale TCP', 'Gabs Remote Tailscale UDP') -join '|')
    }

    It 'LAN TCP: portas, perfil Privado e só a sub-rede local' {
        $r = $script:regras | Where-Object Nome -eq 'Gabs Remote LAN TCP'
        $r.Protocolo | Should -Be 'TCP'
        ($r.Portas -join ',') | Should -Be '47984,47989,47990,48010'
        $r.Perfil | Should -Be 'Private'
        $r.EnderecoRemoto | Should -Be 'LocalSubnet'
    }

    It 'LAN UDP: portas (inclui o relógio do medidor, 48100), perfil Privado e sub-rede local' {
        $r = $script:regras | Where-Object Nome -eq 'Gabs Remote LAN UDP'
        $r.Protocolo | Should -Be 'UDP'
        ($r.Portas -join ',') | Should -Be '47998,47999,48000,48002,48010,48100'
        $r.Perfil | Should -Be 'Private'
        $r.EnderecoRemoto | Should -Be 'LocalSubnet'
    }

    It 'Tailscale: qualquer perfil, só os endereços da tailnet' {
        foreach ($nome in 'Gabs Remote Tailscale TCP', 'Gabs Remote Tailscale UDP') {
            $r = $script:regras | Where-Object Nome -eq $nome
            $r.Perfil | Should -Be 'Any'
            ($r.EnderecoRemoto -join ',') | Should -Be '100.64.0.0/10,fd7a:115c:a1e0::/48'
        }
        ($script:regras | Where-Object Nome -eq 'Gabs Remote Tailscale UDP').Portas -join ',' |
            Should -Be '47998,47999,48000,48002,48010,48100'
    }

    It 'o painel (47990) não fica aberto pelo Tailscale' {
        $tcp = $script:regras | Where-Object Nome -eq 'Gabs Remote Tailscale TCP'
        ($tcp.Portas -join ',') | Should -Be '47984,47989,48010'
        $tcp.Portas | Should -Not -Contain 47990
    }
}

Describe 'Get-ArgumentosRecuperacao' {
    It 'reinicia o serviço 3 vezes (5 s, 5 s, 30 s) e zera a contagem em 1 dia' {
        (Get-ArgumentosRecuperacao) -join ' ' |
            Should -Be 'failure GabsRemote reset= 86400 actions= restart/5000/restart/5000/restart/30000'
    }
}
