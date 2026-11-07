# Testes Pester: o serviço do host se chama GabsRemote (Task 3 do plano da fase 2).
# Rodar: Invoke-Pester C:\gr\tools\marca\servico.Tests.ps1

BeforeAll {
    $script:pastaHost = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'host'
}

Describe 'Nome do serviço do host' {
    It 'nenhum arquivo do host usa mais o nome SunshineService' {
        $pastas = 'src', 'tools', 'src_assets\windows\misc' | ForEach-Object { Join-Path $script:pastaHost $_ }
        $achados = Get-ChildItem -Path $pastas -Recurse -File |
            Select-String -SimpleMatch 'SunshineService' |
            Where-Object { $_.Line -notmatch 'Gabs Remote: remove o serviço antigo' -and $_.Line -notmatch 'set OLD_SERVICE_NAME=SunshineService' }
        $achados | ForEach-Object { "$($_.Path):$($_.LineNumber): $($_.Line.Trim())" } | Should -BeNullOrEmpty
    }

    It 'install-service.bat cria o serviço GabsRemote' {
        $bat = Join-Path $script:pastaHost 'src_assets\windows\misc\service\install-service.bat'
        (Get-Content -LiteralPath $bat) -contains 'set SERVICE_NAME=GabsRemote' | Should -BeTrue
    }

    It 'install-service.bat usa o nome exibido Gabs Remote' {
        $bat = Join-Path $script:pastaHost 'src_assets\windows\misc\service\install-service.bat'
        Get-Content -LiteralPath $bat -Raw | Should -Match 'displayname= "Gabs Remote"'
    }
}
