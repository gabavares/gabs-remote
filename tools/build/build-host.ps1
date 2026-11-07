<#
.SYNOPSIS
    Compila o host (fork do Sunshine) no MSYS2 UCRT64.
.DESCRIPTION
    Roda a partir de C:\gr (a junção sem espaço). Configura com CMake + Ninja em host\build
    e compila. Com -Testes, roda também o binário de testes do upstream.
    Sai com código diferente de 0 em qualquer falha.
.PARAMETER Clean
    Apaga host\build antes de configurar.
.PARAMETER Testes
    Roda build\tests\test_sunshine.exe depois do build.
.PARAMETER Jobs
    Quantas compilações em paralelo (padrão 8).
.EXAMPLE
    powershell -File C:\gr\tools\build\build-host.ps1 -Testes
#>
[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$Testes,
    # Compilações em paralelo. Com 16 GB de RAM, 16 processos do gcc estouram a memória.
    [int]$Jobs = 8
)
$ErrorActionPreference = 'Stop'

$atual = (Get-Location).Path
if ($atual -match '\s' -or $PSScriptRoot -match '\s') {
    Write-Host "ERRO: caminho com espaço ('$atual'). MSYS2, CMake e Ninja quebram com espaço." -ForegroundColor Red
    Write-Host "Use a junção sem espaço: cd C:\gr; powershell -File C:\gr\tools\build\build-host.ps1" -ForegroundColor Red
    exit 2
}

$bash = 'C:\msys64\usr\bin\bash.exe'
if (-not (Test-Path $bash)) {
    Write-Host 'ERRO: MSYS2 não encontrado em C:\msys64. Veja docs\ambiente.md.' -ForegroundColor Red
    exit 3
}

$hostDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'host'
if (-not (Test-Path (Join-Path $hostDir 'CMakeLists.txt'))) {
    Write-Host "ERRO: submódulo host\ não encontrado em $hostDir. Rode: git submodule update --init --recursive" -ForegroundColor Red
    exit 4
}

$env:MSYSTEM = 'UCRT64'
$env:CHERE_INVOKING = '1'
# O Sunshine exige o Node nativo do Windows (o do MSYS2 não serve): herdar o PATH do Windows.
$env:MSYS2_PATH_TYPE = 'inherit'

function Invoke-Ucrt64 {
    param([string]$Comando)
    Write-Host ">> $Comando" -ForegroundColor Cyan
    & $bash -lc $Comando
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: falhou (código $LASTEXITCODE): $Comando" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Push-Location $hostDir
try {
    if ($Clean -and (Test-Path 'build')) {
        Remove-Item -Recurse -Force 'build'
    }
    $opcaoTestes = if ($Testes) { 'ON' } else { 'OFF' }
    # O git do MSYS2, chamado pelo CMake (processo nativo), não acha sed/basename e quebra o
    # "git submodule" do FetchContent. Usa o Git for Windows.
    $gitWin = 'C:/Program Files/Git/cmd/git.exe'
    if (-not (Test-Path $gitWin)) {
        Write-Host "ERRO: Git for Windows não encontrado em $gitWin." -ForegroundColor Red
        exit 3
    }
    Invoke-Ucrt64 "cmake -B build -G Ninja -S . -DBUILD_DOCS=OFF -DBUILD_TESTS=$opcaoTestes '-DGIT_EXECUTABLE=$gitWin'"
    Invoke-Ucrt64 "ninja -C build -j $Jobs"

    if (-not (Test-Path 'build\sunshine.exe')) {
        Write-Host 'ERRO: build terminou mas build\sunshine.exe não existe.' -ForegroundColor Red
        exit 5
    }
    Write-Host 'OK: build\sunshine.exe gerado.' -ForegroundColor Green

    if ($Testes) {
        # Roda dentro de build/tests: os testes gravam arquivos no diretório atual.
        Invoke-Ucrt64 'cd build/tests && ./test_sunshine.exe'
        Write-Host 'OK: testes do upstream passaram.' -ForegroundColor Green
    }
} finally {
    Pop-Location
}
exit 0
