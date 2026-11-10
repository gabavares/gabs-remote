# Testes Pester do Release.psm1 (Tasks 2 e 3 do plano da fase 4).
# Rodar: Invoke-Pester C:\gr\tools\release\Release.Tests.ps1

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot 'Release.psm1') -Force
    $script:dados = Join-Path $PSScriptRoot 'testdata'
    $script:pubTeste = (Get-Content -LiteralPath (Join-Path $script:dados 'chave-de-teste.pub.b64') -Raw).Trim()

    function script:Escrever-Versao([string]$conteudo) {
        $arq = Join-Path $TestDrive ('versao-' + [guid]::NewGuid().ToString('N') + '.json')
        [IO.File]::WriteAllText($arq, $conteudo, (New-Object Text.UTF8Encoding $false))
        $arq
    }

    function script:Manifesto-Valido {
        $obj = [ordered]@{
            schema  = 1
            version = '0.4.1'
            date    = '2026-11-20'
            notes   = 'teste'
            host    = [ordered]@{ file = 'GabsRemote-Setup-0.4.1.exe'; sha256 = ('a' * 64); size = 10; minApp = '0.4.0' }
            app     = [ordered]@{ file = 'GabsRemote-0.4.1.apk'; sha256 = ('b' * 64); size = 20; versionCode = 4001; minHost = '0.4.0' }
        }
        $obj
    }
}

Describe 'Get-VersaoGabs' {
    It 'lê o versao.json do repositório' {
        $v = Get-VersaoGabs
        $v.Version | Should -Match '^\d{1,3}\.\d{1,3}\.\d{1,3}$'
        $v.MinApp | Should -Match '^\d{1,3}\.\d{1,3}\.\d{1,3}$'
        $v.MinHost | Should -Match '^\d{1,3}\.\d{1,3}\.\d{1,3}$'
    }

    It 'lê um arquivo indicado' {
        $arq = Escrever-Versao '{"version": "0.4.0", "minApp": "0.3.9", "minHost": "0.4.0"}'
        $v = Get-VersaoGabs -Arquivo $arq
        $v.Version | Should -Be '0.4.0'
        $v.MinApp | Should -Be '0.3.9'
        $v.MinHost | Should -Be '0.4.0'
    }

    It 'recusa "v0.4"' {
        $arq = Escrever-Versao '{"version": "v0.4", "minApp": "0.4.0", "minHost": "0.4.0"}'
        { Get-VersaoGabs -Arquivo $arq } | Should -Throw
    }

    It 'recusa "1.2.3-beta"' {
        $arq = Escrever-Versao '{"version": "0.4.0", "minApp": "1.2.3-beta", "minHost": "0.4.0"}'
        { Get-VersaoGabs -Arquivo $arq } | Should -Throw
    }
}

Describe 'Get-VersionCode' {
    It '0.4.0 = 4000' { Get-VersionCode -Versao '0.4.0' | Should -Be 4000 }
    It '1.2.3 = 1002003' { Get-VersionCode -Versao '1.2.3' | Should -Be 1002003 }
    It '0.4.1 = 4001' { Get-VersionCode -Versao '0.4.1' | Should -Be 4001 }
    It 'recusa versão inválida' { { Get-VersionCode -Versao '0.4' } | Should -Throw }
}

Describe 'New-Manifesto' {
    BeforeAll {
        $script:exe = Join-Path $TestDrive 'setup.exe'
        $script:apk = Join-Path $TestDrive 'app.apk'
        [IO.File]::WriteAllBytes($script:exe, [Text.Encoding]::ASCII.GetBytes('abc'))
        [IO.File]::WriteAllBytes($script:apk, [Text.Encoding]::ASCII.GetBytes('hello world'))
        $script:json = New-Manifesto -Versao '0.4.1' -Data '2026-11-20' -Notas "Primeira linha.`nSegunda: ação ""entre aspas""." `
            -Instalador $script:exe -Apk $script:apk -MinApp '0.4.0' -MinHost '0.4.0'
        $script:obj = $script:json | ConvertFrom-Json
    }

    It 'calcula SHA-256 e tamanhos dos arquivos' {
        $script:obj.host.sha256 | Should -BeExactly 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
        $script:obj.host.size | Should -Be 3
        $script:obj.app.sha256 | Should -BeExactly 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9'
        $script:obj.app.size | Should -Be 11
    }

    It 'usa os nomes de arquivo da Release e o versionCode da versão' {
        $script:obj.host.file | Should -Be 'GabsRemote-Setup-0.4.1.exe'
        $script:obj.app.file | Should -Be 'GabsRemote-0.4.1.apk'
        $script:obj.app.versionCode | Should -Be 4001
        $script:obj.host.minApp | Should -Be '0.4.0'
        $script:obj.app.minHost | Should -Be '0.4.0'
        $script:obj.schema | Should -Be 1
    }

    It 'preserva as notas (quebra de linha, acento e aspas)' {
        $script:obj.notes | Should -BeExactly "Primeira linha.`nSegunda: ação ""entre aspas""."
    }

    It 'campos na ordem do formato, com \n e sem \r' {
        $script:json | Should -Not -Match "`r"
        $ordem = 'schema', 'version', 'date', 'notes', 'host', 'app' | ForEach-Object { $script:json.IndexOf('"' + $_ + '"') }
        ($ordem | Sort-Object) -join ',' | Should -Be ($ordem -join ',')
    }

    It 'o resultado passa no Test-Manifesto' {
        Test-Manifesto -Json $script:json | Should -BeTrue
    }
}

Describe 'Test-Manifesto' {
    It 'aceita um manifesto válido' {
        Test-Manifesto -Json (Manifesto-Valido | ConvertTo-Json -Depth 4) | Should -BeTrue
    }

    It 'recusa file com ..' {
        $m = Manifesto-Valido; $m.host.file = '..\x.exe'
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa sha256 maiúsculo' {
        $m = Manifesto-Valido; $m.app.sha256 = ('B' * 64)
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa sha256 com 63 dígitos' {
        $m = Manifesto-Valido; $m.host.sha256 = ('a' * 63)
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa schema 2' {
        $m = Manifesto-Valido; $m.schema = 2
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa versionCode que não bate com a versão' {
        $m = Manifesto-Valido; $m.app.versionCode = 4000
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa size zero' {
        $m = Manifesto-Valido; $m.host.size = 0
        Test-Manifesto -Json ($m | ConvertTo-Json -Depth 4) | Should -BeFalse
    }

    It 'recusa JSON quebrado' {
        Test-Manifesto -Json '{"schema": 1' | Should -BeFalse
    }
}

Describe 'Assinatura do manifesto' {
    It 'a fixture confere com a chave de teste' {
        Test-AssinaturaManifesto -Manifesto (Join-Path $script:dados 'manifest.json') `
            -Assinatura (Join-Path $script:dados 'manifest.json.sig') -ChavePublicaBase64 $script:pubTeste | Should -BeTrue
    }

    It 'o manifesto adulterado não confere' {
        Test-AssinaturaManifesto -Manifesto (Join-Path $script:dados 'manifest-adulterado.json') `
            -Assinatura (Join-Path $script:dados 'manifest.json.sig') -ChavePublicaBase64 $script:pubTeste | Should -BeFalse
    }

    It 'a assinatura de outra chave não confere' {
        Test-AssinaturaManifesto -Manifesto (Join-Path $script:dados 'manifest.json') `
            -Assinatura (Join-Path $script:dados 'manifest-outra-chave.json.sig') -ChavePublicaBase64 $script:pubTeste | Should -BeFalse
    }

    It 'assinar e conferir de novo dá certo (64 bytes)' {
        $m = Join-Path $TestDrive 'm.json'
        [IO.File]::WriteAllText($m, '{"schema": 1}', (New-Object Text.UTF8Encoding $false))
        Invoke-AssinarManifesto -Manifesto $m -Chave (Join-Path $script:dados 'chave-de-teste.pem')
        (Get-Item -LiteralPath "$m.sig").Length | Should -Be 64
        Test-AssinaturaManifesto -Manifesto $m -Assinatura "$m.sig" -ChavePublicaBase64 $script:pubTeste | Should -BeTrue
    }

    It 'Get-ChavePublica tira a pública da chave de teste' {
        Get-ChavePublica -Chave (Join-Path $script:dados 'chave-de-teste.pem') | Should -BeExactly $script:pubTeste
    }

    It 'a fixture é válida pelas regras e tem a versão 0.4.1' {
        $json = [IO.File]::ReadAllText((Join-Path $script:dados 'manifest.json'))
        Test-Manifesto -Json $json | Should -BeTrue
        ($json | ConvertFrom-Json).version | Should -Be '0.4.1'
    }
}
