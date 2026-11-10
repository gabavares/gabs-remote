# Gera a fixture de teste do manifesto (Task 2 do plano da fase 4).
# Rodar uma vez e commitar: os bytes ficam fixos e os testes do host, do app e da
# ferramenta usam os mesmos arquivos. A chave de TESTE é pública por definição.
#   powershell -File C:\gr\tools\release\gerar-fixture.ps1
[CmdletBinding()]
param(
    [string]$Pasta
)
$ErrorActionPreference = 'Stop'
# No PowerShell 5.1, $PSScriptRoot fica vazio nos padrões do param().
if (-not $Pasta) { $Pasta = Join-Path $PSScriptRoot 'testdata' }
Import-Module (Join-Path $PSScriptRoot 'Release.psm1') -Force

$openssl = Get-OpenSsl
New-Item -ItemType Directory -Force -Path $Pasta | Out-Null
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('gabs-fixture-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $chave = Join-Path $Pasta 'chave-de-teste.pem'
    & $openssl genpkey -algorithm ed25519 -out $chave
    if ($LASTEXITCODE -ne 0) { throw 'openssl genpkey falhou' }
    $pub = Get-ChavePublica -Chave $chave
    [IO.File]::WriteAllText((Join-Path $Pasta 'chave-de-teste.pub.b64'), $pub + "`n", (New-Object Text.UTF8Encoding $false))

    # Arquivos fictícios: só os hashes e os tamanhos entram no manifesto.
    $exe = Join-Path $tmp 'GabsRemote-Setup-0.4.1.exe'
    $apk = Join-Path $tmp 'GabsRemote-0.4.1.apk'
    [IO.File]::WriteAllBytes($exe, [Text.Encoding]::ASCII.GetBytes('instalador de teste do Gabs Remote 0.4.1'))
    [IO.File]::WriteAllBytes($apk, [Text.Encoding]::ASCII.GetBytes('apk de teste do Gabs Remote 0.4.1'))

    $notas = "Versão de teste.`n- Linha com acento: atualização.`n- Linha com ""aspas""."
    $json = New-Manifesto -Versao '0.4.1' -Data '2026-11-20' -Notas $notas -Instalador $exe -Apk $apk -MinApp '0.4.0' -MinHost '0.4.0'
    $manifesto = Join-Path $Pasta 'manifest.json'
    [IO.File]::WriteAllText($manifesto, $json, (New-Object Text.UTF8Encoding $false))
    Invoke-AssinarManifesto -Manifesto $manifesto -Chave $chave

    # Adulterado: troca um dígito do sha256 do host, mantendo o resto igual.
    $obj = $json | ConvertFrom-Json
    $h = $obj.host.sha256
    $trocado = $h.Substring(0, 10) + $(if ($h[10] -eq '0') { '1' } else { '0' }) + $h.Substring(11)
    [IO.File]::WriteAllText((Join-Path $Pasta 'manifest-adulterado.json'), $json.Replace($h, $trocado), (New-Object Text.UTF8Encoding $false))

    # Assinatura feita com uma segunda chave, descartada em seguida.
    $outra = Join-Path $tmp 'outra.pem'
    & $openssl genpkey -algorithm ed25519 -out $outra
    if ($LASTEXITCODE -ne 0) { throw 'openssl genpkey falhou' }
    Invoke-AssinarManifesto -Manifesto $manifesto -Chave $outra -Saida (Join-Path $Pasta 'manifest-outra-chave.json.sig')

    Write-Host "Fixture gerada em $Pasta (chave pública de teste: $pub)"
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
