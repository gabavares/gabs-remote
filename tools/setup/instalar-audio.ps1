<#
.SYNOPSIS
    Instala o VB-CABLE, o cabo de áudio virtual que vira o microfone do tablet no Windows
    (decisão 0007). Roda uma vez por instalação do Windows.
.DESCRIPTION
    Precisa rodar como administrador e pelo caminho sem espaço C:\gr (código 2 se não for).
      1. confere os dispositivos de áudio; se "CABLE Output" já existe, não faz nada;
      2. baixa o pacote oficial do VB-CABLE (vb-audio.com) para %TEMP%\gabs-remote-vbcable\ e
         confere o SHA-256 fixado abaixo (código 3 se não bater);
      3. extrai e roda VBCABLE_Setup_x64.exe -i -h (instalação silenciosa);
      4. confere que "CABLE Output" apareceu (código 4 se não) e que a saída padrão do Windows
         continua a mesma; se mudou para o cabo, volta a anterior.
    O VB-CABLE é donationware (VB-Audio): não vai dentro do instalador do Gabs Remote.
    No Windows o host escreve em "Alto-falantes (VB-Audio Virtual Cable)" (Reprodução) e o microfone
    do tablet aparece como "CABLE Output (VB-Audio Virtual Cable)" (Gravação).
    As caixas do PC em silêncio usam o "Steam Streaming Speakers"; o script só avisa se faltar.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\gr\tools\setup\instalar-audio.ps1
#>
[CmdletBinding()]
param()

# Pacote oficial conferido em 11/11/2026 (VBCABLE_Driver_Pack46, driver de 31/10/2026, catálogo
# assinado pela Microsoft Windows Hardware Compatibility Publisher; setup assinado por BUREL VINCENT).
$UrlVbCable = 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack46.zip'
$Sha256VbCable = 'BC44E8974191A5A2427D6C979E2DAB08DBB09925F3F435DFA2F0BA3E45B6EB90'

function Test-PacoteVbCable {
    param(
        [Parameter(Mandatory)][string]$Caminho,
        [string]$Esperado = $Sha256VbCable
    )
    if (-not (Test-Path -LiteralPath $Caminho)) { return $false }
    $hash = (Get-FileHash -LiteralPath $Caminho -Algorithm SHA256).Hash
    return ($hash -eq $Esperado.ToUpperInvariant())
}

function Get-DispositivosAudio {
    @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'OK' | ForEach-Object FriendlyName)
}

function Get-PassosInstalacao {
    param([string[]]$Dispositivos = @())
    $passos = @()
    if (-not ($Dispositivos | Where-Object { $_ -like 'CABLE Output*' })) { $passos += 'VB-CABLE' }
    return $passos
}

function Get-AvisoAltoFalanteVirtual {
    param([string[]]$Dispositivos = @())
    if ($Dispositivos | Where-Object { $_ -like '*Steam Streaming Speakers*' }) { return $null }
    return 'Aviso: "Steam Streaming Speakers" não existe neste PC. Sem ele as caixas do PC não ficam em silêncio durante a sessão: instale o Steam ou use "Tocar som no PC" ligado.'
}

# Saída padrão do Windows (IMMDeviceEnumerator) e troca (IPolicyConfig, interface não documentada,
# a mesma que o Sunshine usa para o virtual_sink).
$CodigoAudioPadrao = @'
using System;
using System.Runtime.InteropServices;
namespace GabsRemote {
  [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDeviceEnumerator {
    int NotImpl1();
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
  }
  [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IMMDevice {
    int Activate(); int OpenPropertyStore();
    [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
  }
  [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  interface IPolicyConfig {
    int a(); int b(); int c(); int d(); int e(); int f(); int g(); int h(); int i(); int j();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
  }
  [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumerator {}
  [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")] class PolicyConfigClient {}
  public static class AudioPadrao {
    public static string Saida() {
      var e = (IMMDeviceEnumerator)new MMDeviceEnumerator();
      IMMDevice d;
      if (e.GetDefaultAudioEndpoint(0, 1, out d) != 0) return null;
      string id; d.GetId(out id); return id;
    }
    public static void Definir(string id) {
      var p = (IPolicyConfig)new PolicyConfigClient();
      for (int role = 0; role < 3; role++) p.SetDefaultEndpoint(id, role);
    }
  }
}
'@

function Get-SaidaPadrao {
    if (-not ('GabsRemote.AudioPadrao' -as [type])) { Add-Type -TypeDefinition $CodigoAudioPadrao }
    [GabsRemote.AudioPadrao]::Saida()
}

function Set-SaidaPadrao([string]$Id) {
    if (-not ('GabsRemote.AudioPadrao' -as [type])) { Add-Type -TypeDefinition $CodigoAudioPadrao }
    [GabsRemote.AudioPadrao]::Definir($Id)
}

if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'

if ($PSScriptRoot -match '\s') {
    Write-Host "ERRO: caminho com espaço ('$PSScriptRoot'). Rode por C:\gr: powershell -File C:\gr\tools\setup\instalar-audio.ps1" -ForegroundColor Red
    exit 2
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'ERRO: rode este script como administrador (instala um driver de áudio).' -ForegroundColor Red
    exit 2
}

$dispositivos = Get-DispositivosAudio
$aviso = Get-AvisoAltoFalanteVirtual -Dispositivos $dispositivos
if ($aviso) { Write-Host $aviso -ForegroundColor Yellow }

if (@(Get-PassosInstalacao -Dispositivos $dispositivos).Count -eq 0) {
    Write-Host 'OK: o VB-CABLE já está instalado ("CABLE Output" existe). Nada a fazer.' -ForegroundColor Green
    exit 0
}

$saidaAntes = Get-SaidaPadrao
$pasta = Join-Path $env:TEMP 'gabs-remote-vbcable'
New-Item -ItemType Directory -Force -Path $pasta | Out-Null
$zip = Join-Path $pasta (Split-Path $UrlVbCable -Leaf)

Write-Host ">> Baixando $UrlVbCable" -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $UrlVbCable -OutFile $zip -UseBasicParsing
if (-not (Test-PacoteVbCable -Caminho $zip)) {
    Remove-Item -LiteralPath $zip -Force
    Write-Host "ERRO: o pacote baixado não tem o SHA-256 esperado ($Sha256VbCable). A VB-Audio pode ter trocado a versão: confira o site e atualize o script." -ForegroundColor Red
    exit 3
}

$extraido = Join-Path $pasta 'pacote'
if (Test-Path -LiteralPath $extraido) { Remove-Item -LiteralPath $extraido -Recurse -Force }
Expand-Archive -LiteralPath $zip -DestinationPath $extraido
Write-Host '>> VBCABLE_Setup_x64.exe -i -h' -ForegroundColor Cyan
$p = Start-Process -FilePath (Join-Path $extraido 'VBCABLE_Setup_x64.exe') -ArgumentList '-i', '-h' -Wait -PassThru
Write-Host "   saiu com o código $($p.ExitCode)"

$ok = $false
for ($i = 0; $i -lt 15 -and -not $ok; $i++) {
    Start-Sleep -Seconds 1
    $ok = [bool](Get-DispositivosAudio | Where-Object { $_ -like 'CABLE Output*' })
}
if (-not $ok) {
    Write-Host "ERRO: `"CABLE Output`" não apareceu. Reinicie o PC e rode o script de novo; se continuar, instale à mão pelo VBCABLE_Setup_x64.exe em $extraido" -ForegroundColor Red
    exit 4
}

$saidaDepois = Get-SaidaPadrao
if ($saidaAntes -and $saidaDepois -ne $saidaAntes) {
    Set-SaidaPadrao $saidaAntes
    Write-Host 'A instalação trocou a saída padrão do Windows; voltei para a anterior.' -ForegroundColor Yellow
}

Write-Host 'OK: VB-CABLE instalado. No Windows, o microfone do tablet aparece como "CABLE Output (VB-Audio Virtual Cable)".' -ForegroundColor Green
exit 0
