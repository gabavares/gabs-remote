<#
.SYNOPSIS
    Verifica se o PC tem tudo o que o Gabs Remote precisa para compilar.
.DESCRIPTION
    Imprime uma linha por ferramenta ("OK <nome> <versão>" ou "FALTA <nome> — <como instalar>")
    e sai com código 0 só se tudo estiver OK.
    Pode ser carregado por dot-source para usar Test-Ferramenta e Test-CaminhoSemEspaco.
.PARAMETER Json
    Imprime o resultado em JSON em vez de texto.
.PARAMETER SemAndroid
    Pula a verificação do Android SDK e do NDK.
#>
[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$SemAndroid
)

function Test-CaminhoSemEspaco {
    param([Parameter(Mandatory, Position = 0)][string]$Caminho)
    return -not ($Caminho -match '\s')
}

function Test-Ferramenta {
    param(
        [Parameter(Mandatory)][string]$Nome,
        [Parameter(Mandatory)][scriptblock]$Comando,
        [Parameter(Mandatory)][version]$VersaoMinima,
        [string]$Dica
    )
    if (-not $Dica) { $Dica = "instale ou atualize $Nome (mínimo $VersaoMinima)" }
    $versao = $null
    try {
        $saida = (& $Comando 2>&1 | Out-String)
        if ($saida -match '\d+(\.\d+)+') { $versao = $Matches[0] }
    } catch {
        $versao = $null
    }
    $ok = $false
    if ($versao) {
        try { $ok = ([version]$versao) -ge $VersaoMinima } catch { $ok = $false }
    }
    [pscustomobject]@{
        Nome   = $Nome
        Ok     = $ok
        Versao = $versao
        Dica   = $(if ($ok) { '' } else { $Dica })
    }
}

function New-Resultado {
    param([string]$Nome, [bool]$Ok, [string]$Versao, [string]$Dica)
    [pscustomobject]@{ Nome = $Nome; Ok = $Ok; Versao = $Versao; Dica = $(if ($Ok) { '' } else { $Dica }) }
}

function Get-VersaoNdkPedida {
    param([string]$Raiz)
    $gradle = Join-Path $Raiz 'android\app\build.gradle'
    if (-not (Test-Path $gradle)) { return $null }
    $m = Select-String -Path $gradle -Pattern 'ndkVersion\s*[=]?\s*["'']([\d\.]+)["'']' | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
    return $null
}

function Invoke-Verificacao {
    param([switch]$SemAndroid)
    $raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $ucrt = 'C:\msys64\ucrt64\bin'
    $r = @()

    $r += Test-Ferramenta -Nome 'git' -Comando { git --version } -VersaoMinima '2.40' `
        -Dica 'winget install --id Git.Git'
    $r += Test-Ferramenta -Nome 'gh' -Comando { gh --version } -VersaoMinima '2.40' `
        -Dica 'winget install --id GitHub.cli'
    # O CMake do host usa o Git for Windows (o git do MSYS2 quebra o FetchContent).
    $gitWin = 'C:\Program Files\Git\cmd\git.exe'
    $r += Test-Ferramenta -Nome 'git-for-windows' -Comando { & $gitWin --version } -VersaoMinima '2.40' `
        -Dica 'winget install --id Git.Git (o build-host usa C:\Program Files\Git\cmd\git.exe)'
    # O painel web do Sunshine exige o Node nativo do Windows (o do MSYS2 não serve).
    $r += Test-Ferramenta -Nome 'node' -Comando { node --version } -VersaoMinima '20.0' `
        -Dica 'winget install --id OpenJS.NodeJS.LTS'

    $gcc = Join-Path $ucrt 'gcc.exe'
    $r += New-Resultado -Nome 'msys2-ucrt64' -Ok (Test-Path $gcc) -Versao $(if (Test-Path $gcc) { 'gcc' } else { '' }) `
        -Dica 'winget install --id MSYS2.MSYS2 e, no UCRT64, pacman -S mingw-w64-ucrt-x86_64-toolchain'
    $r += Test-Ferramenta -Nome 'cmake (ucrt64)' -Comando { & (Join-Path $ucrt 'cmake.exe') --version } -VersaoMinima '3.20' `
        -Dica 'no UCRT64: pacman -S mingw-w64-ucrt-x86_64-cmake'
    $r += Test-Ferramenta -Nome 'ninja (ucrt64)' -Comando { & (Join-Path $ucrt 'ninja.exe') --version } -VersaoMinima '1.10' `
        -Dica 'no UCRT64: pacman -S mingw-w64-ucrt-x86_64-ninja'

    $r += Test-Ferramenta -Nome 'jdk' -Comando { cmd /c 'java -version 2>&1' } -VersaoMinima '17.0' `
        -Dica 'winget install --id EclipseAdoptium.Temurin.17.JDK'

    if (-not $SemAndroid) {
        $sdk = $env:ANDROID_HOME
        $adb = if ($sdk) { Join-Path $sdk 'platform-tools\adb.exe' } else { '' }
        $temAdb = [bool]($adb -and (Test-Path $adb))
        $r += New-Resultado -Nome 'android-sdk' -Ok $temAdb -Versao $(if ($temAdb) { $sdk } else { '' }) `
            -Dica 'defina ANDROID_HOME (C:\Android\sdk) e rode sdkmanager "platform-tools"'

        $ndkPedido = Get-VersaoNdkPedida -Raiz $raiz
        if ($ndkPedido) {
            $temNdk = [bool]($sdk -and (Test-Path (Join-Path $sdk "ndk\$ndkPedido")))
            $r += New-Resultado -Nome 'android-ndk' -Ok $temNdk -Versao $(if ($temNdk) { $ndkPedido } else { '' }) `
                -Dica "sdkmanager `"ndk;$ndkPedido`""
        } else {
            $r += New-Resultado -Nome 'android-ndk' -Ok $false -Versao '' `
                -Dica 'submódulo android/ ainda não existe (Task 4 da fase 1)'
        }
    }

    $pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
    $r += Test-Ferramenta -Nome 'pester' -Comando { "$($pester.Version)" } -VersaoMinima '5.0' `
        -Dica 'Install-Module Pester -MinimumVersion 5 -Scope CurrentUser -Force -SkipPublisherCheck'

    $gr = Get-Item 'C:\gr' -ErrorAction SilentlyContinue
    $juncaoOk = [bool]($gr -and $gr.LinkType -eq 'Junction' -and (Test-Path 'C:\gr\tools\setup\verificar-ambiente.ps1'))
    $r += New-Resultado -Nome 'juncao C:\gr' -Ok $juncaoOk -Versao $(if ($juncaoOk) { 'C:\gr' } else { '' }) `
        -Dica "cmd /c mklink /J C:\gr `"$raiz`""

    return $r
}

if ($MyInvocation.InvocationName -ne '.') {
    $resultados = Invoke-Verificacao -SemAndroid:$SemAndroid
    if ($Json) {
        $resultados | ConvertTo-Json
    } else {
        foreach ($x in $resultados) {
            if ($x.Ok) { "OK $($x.Nome) $($x.Versao)" } else { "FALTA $($x.Nome) — $($x.Dica)" }
        }
    }
    if ($resultados | Where-Object { -not $_.Ok }) { exit 1 } else { exit 0 }
}
