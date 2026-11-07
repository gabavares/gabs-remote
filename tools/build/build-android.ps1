<#
.SYNOPSIS
    Compila o app Android (fork do moonlight-android).
.DESCRIPTION
    Roda a partir de C:\gr (a junção sem espaço). Gera o APK de debug da variante nonRoot.
    Com -Testes, roda também os testes unitários. Com -Release, gera o APK de release assinado
    com a keystore do Gab (exige %USERPROFILE%\.gabs-remote\keystore.properties ou a variável
    GABS_KEYSTORE_PROPS; sem ele sai com código 5). Com -Instalar, instala o APK gerado pelo adb
    no aparelho conectado. Sai com código diferente de 0 em qualquer falha.
.EXAMPLE
    powershell -File C:\gr\tools\build\build-android.ps1 -Testes -Instalar
.EXAMPLE
    powershell -File C:\gr\tools\build\build-android.ps1 -Release -Instalar
#>
[CmdletBinding()]
param(
    [switch]$Testes,
    [switch]$Release,
    [switch]$Instalar
)
$ErrorActionPreference = 'Stop'

$atual = (Get-Location).Path
if ($atual -match '\s' -or $PSScriptRoot -match '\s') {
    Write-Host "ERRO: caminho com espaço ('$atual'). Gradle e o NDK quebram com espaço." -ForegroundColor Red
    Write-Host "Use a junção sem espaço: cd C:\gr; powershell -File C:\gr\tools\build\build-android.ps1" -ForegroundColor Red
    exit 2
}

# Terminais abertos antes da instalação não enxergam as variáveis novas: lê do registro do usuário.
foreach ($v in 'ANDROID_HOME', 'JAVA_HOME') {
    if (-not (Get-Item "env:$v" -ErrorAction SilentlyContinue)) {
        $valor = [Environment]::GetEnvironmentVariable($v, 'User')
        if ($valor) { Set-Item "env:$v" $valor }
    }
}
if (-not $env:ANDROID_HOME -or -not $env:JAVA_HOME) {
    Write-Host 'ERRO: ANDROID_HOME ou JAVA_HOME não definidos. Veja docs\ambiente.md.' -ForegroundColor Red
    exit 3
}

$appDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'android'
if (-not (Test-Path (Join-Path $appDir 'gradlew.bat'))) {
    Write-Host "ERRO: submódulo android\ não encontrado em $appDir. Rode: git submodule update --init --recursive" -ForegroundColor Red
    exit 4
}

if ($Release) {
    $props = if ($env:GABS_KEYSTORE_PROPS) { $env:GABS_KEYSTORE_PROPS } else { Join-Path $env:USERPROFILE '.gabs-remote\keystore.properties' }
    if (-not (Test-Path -LiteralPath $props)) {
        Write-Host "ERRO: $props não existe. O build de release precisa da keystore do Gab (veja docs\segredos.md)." -ForegroundColor Red
        exit 5
    }
}

function Invoke-Passo {
    param([string]$Exe, [string[]]$Argumentos)
    Write-Host ">> $Exe $($Argumentos -join ' ')" -ForegroundColor Cyan
    & $Exe @Argumentos
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: falhou (código $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Push-Location $appDir
try {
    $tipo = if ($Release) { 'release' } else { 'debug' }
    [string[]]$tarefas = if ($Release) { 'assembleNonRootRelease' } else { 'assembleNonRootDebug' }
    if ($Testes) { $tarefas += 'testNonRootDebugUnitTest' }
    Invoke-Passo '.\gradlew.bat' ($tarefas + '--console=plain')

    $apk = Get-ChildItem "app\build\outputs\apk\nonRoot\$tipo\*.apk" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'unsigned' } | Select-Object -First 1
    if (-not $apk) {
        Write-Host "ERRO: build terminou mas o APK assinado não foi encontrado em app\build\outputs\apk\nonRoot\$tipo." -ForegroundColor Red
        exit 6
    }
    Write-Host "OK: APK gerado em $($apk.FullName)" -ForegroundColor Green

    if ($Instalar) {
        $adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
        Invoke-Passo $adb @('install', '-r', $apk.FullName)
        Write-Host 'OK: APK instalado no aparelho.' -ForegroundColor Green
    }
} finally {
    Pop-Location
}
exit 0
