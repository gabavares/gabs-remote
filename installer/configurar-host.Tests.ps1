# Testes Pester do configurar-host.ps1 (Task 6 do plano da fase 4).
# Rodar: Invoke-Pester C:\gr\installer\configurar-host.Tests.ps1

BeforeAll {
    . (Join-Path $PSScriptRoot 'configurar-host.ps1')
}

Describe 'Get-RegrasFirewall' {
    BeforeAll { $script:regras = @(Get-RegrasFirewall) }

    It 'devolve as 4 regras, todas com nome começando por "Gabs Remote "' {
        $script:regras.Count | Should -Be 4
        ($script:regras.Nome | Sort-Object) -join '|' | Should -Be (@(
            'Gabs Remote LAN TCP', 'Gabs Remote LAN UDP',
            'Gabs Remote Tailscale TCP', 'Gabs Remote Tailscale UDP') -join '|')
        foreach ($r in $script:regras) { $r.Nome | Should -BeLike 'Gabs Remote *' }
    }

    It 'nenhuma regra sem RemoteAddress restrito (só a sub-rede local ou a tailnet)' {
        $permitidos = 'LocalSubnet', '100.64.0.0/10', 'fd7a:115c:a1e0::/48'
        foreach ($r in $script:regras) {
            @($r.EnderecoRemoto).Count | Should -BeGreaterThan 0
            foreach ($e in @($r.EnderecoRemoto)) { $permitidos | Should -Contain $e }
        }
    }

    It 'LAN: portas e perfil Privado' {
        $tcp = $script:regras | Where-Object Nome -eq 'Gabs Remote LAN TCP'
        ($tcp.Portas -join ',') | Should -Be '47984,47989,47990,48010'
        $tcp.Perfil | Should -Be 'Private'
        $udp = $script:regras | Where-Object Nome -eq 'Gabs Remote LAN UDP'
        ($udp.Portas -join ',') | Should -Be '47998,47999,48000,48002,48010,48100'
        $udp.Perfil | Should -Be 'Private'
    }

    It 'o painel (47990) não fica aberto pelo Tailscale' {
        $tcp = $script:regras | Where-Object Nome -eq 'Gabs Remote Tailscale TCP'
        ($tcp.Portas -join ',') | Should -Be '47984,47989,48010'
        ($script:regras | Where-Object Nome -eq 'Gabs Remote Tailscale UDP').Portas -join ',' |
            Should -Be '47998,47999,48000,48002,48010,48100'
    }
}

Describe 'Get-ArgumentosRecuperacao' {
    It 'reinicia o serviço 3 vezes (5 s, 5 s, 30 s) e zera a contagem em 1 dia' {
        (Get-ArgumentosRecuperacao) -join ' ' |
            Should -Be 'failure GabsRemote reset= 86400 actions= restart/5000/restart/5000/restart/30000'
    }
}

Describe 'New-AclPastaUpdates' {
    BeforeAll { $script:acl = New-AclPastaUpdates }

    It 'dono Administradores e sem herança' {
        $script:acl.GetOwner([Security.Principal.SecurityIdentifier]).Value | Should -Be 'S-1-5-32-544'
        $script:acl.AreAccessRulesProtected | Should -BeTrue
    }

    It 'só SYSTEM e Administradores, com controle total' {
        $regras = @($script:acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
        $regras.Count | Should -Be 2
        ($regras | ForEach-Object { $_.IdentityReference.Value } | Sort-Object) -join ',' | Should -Be 'S-1-5-18,S-1-5-32-544'
        foreach ($r in $regras) {
            $r.AccessControlType | Should -Be 'Allow'
            $r.FileSystemRights | Should -Be 'FullControl'
        }
    }
}

Describe 'Invoke-ConfigurarHost' {
    BeforeAll {
        $script:pasta = Join-Path $TestDrive 'Gabs Remote'
        New-Item -ItemType Directory -Force -Path (Join-Path $script:pasta 'config') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $script:pasta 'scripts') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $script:pasta 'drivers\sudovda') | Out-Null
        Set-Content -LiteralPath (Join-Path $script:pasta 'config\sunshine.conf') -Value 'x'
        Set-Content -LiteralPath (Join-Path $script:pasta 'sunshine.exe') -Value 'x'
    }

    BeforeEach {
        Mock Invoke-Bat {}
        Mock Invoke-ScRecuperacao {}
        Mock Stop-Servico {}
        Mock Start-Servico {}
        Mock Remove-Regras {}
        Mock Add-Regras {}
        Mock Set-AclPastaUpdates {}
        Mock Remove-Item {}
        Mock Copy-Item {}
        Mock Remove-Servico {}
    }

    It 'atualização nunca instala o SudoVDA' {
        Mock Test-DispositivoSudoVda { $false }
        Invoke-ConfigurarHost -Pasta $script:pasta -Atualizacao
        Should -Invoke Invoke-Bat -Times 0 -ParameterFilter { $Arquivo -like '*sudovda*' }
        Should -Invoke Start-Servico -Times 1
    }

    It 'instalação normal instala o SudoVDA quando o dispositivo não existe' {
        Mock Test-DispositivoSudoVda { $false }
        Invoke-ConfigurarHost -Pasta $script:pasta
        Should -Invoke Invoke-Bat -Times 1 -ParameterFilter { $Arquivo -like '*sudovda*install.bat' }
    }

    It 'instalação normal não reinstala o SudoVDA quando o dispositivo existe' {
        Mock Test-DispositivoSudoVda { $true }
        Invoke-ConfigurarHost -Pasta $script:pasta
        Should -Invoke Invoke-Bat -Times 0 -ParameterFilter { $Arquivo -like '*sudovda*' }
    }

    It 'cria o serviço, a recuperação, as regras e o ACL de config\updates' {
        Mock Test-DispositivoSudoVda { $true }
        Invoke-ConfigurarHost -Pasta $script:pasta
        Should -Invoke Invoke-Bat -Times 1 -ParameterFilter { $Arquivo -like '*install-service.bat' }
        Should -Invoke Invoke-Bat -Times 1 -ParameterFilter { $Arquivo -like '*autostart-service.bat' }
        Should -Invoke Invoke-ScRecuperacao -Times 1
        Should -Invoke Remove-Regras -Times 1
        Should -Invoke Add-Regras -Times 1
        Should -Invoke Set-AclPastaUpdates -Times 1 -ParameterFilter { $Pasta -eq (Join-Path $script:pasta 'config\updates') }
        Test-Path -LiteralPath (Join-Path $script:pasta 'config\updates') | Should -BeTrue
    }

    It 'não toca em config (instalação, atualização e desinstalação)' {
        Mock Test-DispositivoSudoVda { $true }
        Invoke-ConfigurarHost -Pasta $script:pasta
        Invoke-ConfigurarHost -Pasta $script:pasta -Atualizacao
        Invoke-ConfigurarHost -Pasta $script:pasta -Desinstalar
        $config = Join-Path $script:pasta 'config'
        Should -Invoke Remove-Item -Times 0 -ParameterFilter {
            @($Path) + @($LiteralPath) | Where-Object { $_ -and ($_ -eq $config -or $_ -like "$config\*") }
        }
        Should -Invoke Copy-Item -Times 0 -ParameterFilter {
            @($Destination) + @($Path) + @($LiteralPath) | Where-Object { $_ -and ($_ -eq $config -or $_ -like "$config\*") }
        }
    }

    It '-Parar só para o serviço e o host da pasta, sem configurar nada' {
        Mock Stop-HostDaPasta {}
        Mock Test-DispositivoSudoVda { $false }
        Invoke-ConfigurarHost -Pasta $script:pasta -Parar
        Should -Invoke Stop-Servico -Times 1
        Should -Invoke Stop-HostDaPasta -Times 1 -ParameterFilter { $Pasta -eq $script:pasta }
        Should -Invoke Invoke-Bat -Times 0
        Should -Invoke Add-Regras -Times 0
        Should -Invoke Start-Servico -Times 0
        Should -Invoke Set-AclPastaUpdates -Times 0
    }

    It 'desinstalação remove serviço e regras e não inicia nada' {
        Invoke-ConfigurarHost -Pasta $script:pasta -Desinstalar
        Should -Invoke Remove-Servico -Times 1
        Should -Invoke Remove-Regras -Times 1
        Should -Invoke Start-Servico -Times 0
    }
}
