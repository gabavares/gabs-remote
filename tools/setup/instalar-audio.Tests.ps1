# Testes Pester do instalar-audio.ps1 (Task 1 do plano da fase 5).
# Rodar: Invoke-Pester C:\gr\tools\setup\instalar-audio.Tests.ps1

BeforeAll {
    $script:Script = Join-Path $PSScriptRoot 'instalar-audio.ps1'
    . $script:Script
}

Describe 'Test-PacoteVbCable' {
    It 'aceita só o arquivo com o SHA-256 fixado no script' {
        $arq = Join-Path $TestDrive 'pacote.zip'
        Set-Content -LiteralPath $arq -Value 'qualquer coisa' -Encoding ascii
        Test-PacoteVbCable -Caminho $arq | Should -BeFalse
        $hash = (Get-FileHash -LiteralPath $arq -Algorithm SHA256).Hash
        Test-PacoteVbCable -Caminho $arq -Esperado $hash | Should -BeTrue
    }

    It 'arquivo que não existe: recusa' {
        Test-PacoteVbCable -Caminho (Join-Path $TestDrive 'nao-existe.zip') | Should -BeFalse
    }

    It 'o hash fixado tem 64 dígitos hexadecimais e a URL é do site oficial' {
        $Sha256VbCable | Should -Match '^[0-9A-F]{64}$'
        $UrlVbCable | Should -Match '^https://download\.vb-audio\.com/Download_CABLE/VBCABLE_Driver_Pack\d+\.zip$'
    }
}

Describe 'Get-PassosInstalacao' {
    It 'dispositivos já existem: nada a fazer' {
        $d = @('Alto-falantes (VB-Audio Virtual Cable)', 'CABLE Output (VB-Audio Virtual Cable)', 'Alto-falantes (Steam Streaming Speakers)')
        @(Get-PassosInstalacao -Dispositivos $d).Count | Should -Be 0
    }

    It 'sem o CABLE Output: instala o VB-CABLE' {
        $d = @('Alto-falantes (Steam Streaming Speakers)', 'Microfone (HyperX Cloud II Wireless)')
        @(Get-PassosInstalacao -Dispositivos $d) | Should -Be @('VB-CABLE')
    }
}

Describe 'Get-AvisoAltoFalanteVirtual' {
    It 'com o Steam Streaming Speakers: sem aviso' {
        Get-AvisoAltoFalanteVirtual -Dispositivos @('Alto-falantes (Steam Streaming Speakers)') | Should -BeNullOrEmpty
    }
    It 'sem ele: avisa que as caixas do PC não ficam em silêncio' {
        Get-AvisoAltoFalanteVirtual -Dispositivos @('Alto-falantes (Realtek)') | Should -Match 'Steam'
    }
}

Describe 'Recusas do script' -Tag 'Local' {
    It 'caminho com espaço: código 2' {
        $dir = Join-Path $TestDrive 'pasta com espaço'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item $script:Script $dir
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'instalar-audio.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $saida | Should -Match 'espaço'
    }

    It 'sem administrador: código 2' -Skip:(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $dir = Join-Path $TestDrive 'semespaco'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item $script:Script $dir
        $saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir 'instalar-audio.ps1') 2>&1 | Out-String
        $LASTEXITCODE | Should -Be 2
        $saida | Should -Match 'administrador'
    }
}
