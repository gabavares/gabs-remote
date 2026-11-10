; Instalador do Gabs Remote (host Windows). Plano da fase 4, Task 6; decisão 0006.
; Gerado por tools\build\build-instalador.ps1:
;   makensis -DVERSION=<x.y.z> -DSTAGE=<pasta do cmake --install> -DOUTFILE=<exe> -DICON=<ico> gabs-remote.nsi
; Uso:
;   GabsRemote-Setup-<v>.exe                 instalação interativa
;   GabsRemote-Setup-<v>.exe /S /ATUALIZACAO atualização silenciosa (o updater do host chama assim)
; A pasta config (pareamentos, login do painel, sunshine.conf) nunca é sobrescrita nem apagada.

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma

!ifndef VERSION
  !error "passe -DVERSION=x.y.z"
!endif
!ifndef STAGE
  !error "passe -DSTAGE=<pasta>"
!endif
!ifndef OUTFILE
  !define OUTFILE "GabsRemote-Setup-${VERSION}.exe"
!endif

!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

!define NOME "Gabs Remote"
!define EDITOR "Gab Tavares"
!define CHAVE_DESINSTALAR "Software\Microsoft\Windows\CurrentVersion\Uninstall\GabsRemote"
; PowerShell de 64 bits, escolhido em .onInit: o NSIS do MSYS2 gera um instalador de 64 bits ($SYSDIR já
; é o System32 de 64); num stub de 32 bits, Sysnative evita o redirecionamento para SysWOW64.
!define POWERSHELL "$PowerShell"

Name "${NOME}"
Caption "${NOME} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\Gabs Remote"
RequestExecutionLevel admin
ShowInstDetails show
ShowUninstDetails show
BrandingText "${NOME} ${VERSION}"
!ifdef ICON
  Icon "${ICON}"
  UninstallIcon "${ICON}"
!endif

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1046 "ProductName" "${NOME}"
VIAddVersionKey /LANG=1046 "CompanyName" "${EDITOR}"
VIAddVersionKey /LANG=1046 "FileDescription" "Instalador do ${NOME}"
VIAddVersionKey /LANG=1046 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1046 "ProductVersion" "${VERSION}"
VIAddVersionKey /LANG=1046 "LegalCopyright" "GPL-3.0"

LoadLanguageFile "${NSISDIR}\Contrib\Language files\PortugueseBR.nlf"

Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Var Atualizacao
Var PowerShell

!macro EscolherPowerShell
  StrCpy $PowerShell "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  ${IfNot} ${FileExists} "$PowerShell"
    StrCpy $PowerShell "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe"
  ${EndIf}
!macroend

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "O Gabs Remote precisa do Windows de 64 bits."
    SetErrorLevel 3
    Quit
  ${EndIf}
  SetRegView 64
  !insertmacro EscolherPowerShell
  StrCpy $Atualizacao ""
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/ATUALIZACAO" $R1
  ${IfNot} ${Errors}
    StrCpy $Atualizacao "-Atualizacao"
  ${EndIf}
FunctionEnd

Function .onInstFailed
  SetErrorLevel 2
FunctionEnd

Section "Gabs Remote" SecHost
  SectionIn RO
  SetShellVarContext all

  ; 1. Para o serviço e o sunshine.exe desta pasta (o executável vai ser trocado).
  InitPluginsDir
  File "/oname=$PLUGINSDIR\configurar-host.ps1" "${STAGE}\configurar-host.ps1"
  DetailPrint "Parando o Gabs Remote..."
  nsExec::ExecToLog '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\configurar-host.ps1" -Pasta "$INSTDIR" -Parar'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Falha ao parar o serviço (código $0)."
    SetErrorLevel 1
    Abort "Não consegui parar o Gabs Remote."
  ${EndIf}

  ; 2. Arquivos do programa, exceto config.
  SetOverwrite on
  SetOutPath "$INSTDIR"
  File /r /x "config" "${STAGE}\*.*"

  ; 3. config: o instalador nunca grava nela (o host cria os arquivos padrão na primeira execução).

  ; 4. Desinstalador e entrada em "Aplicativos".
  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Desinstalar.exe"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "DisplayName" "${NOME}"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "Publisher" "${EDITOR}"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "DisplayIcon" "$INSTDIR\sunshine.exe"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "UninstallString" '"$INSTDIR\Desinstalar.exe"'
  WriteRegStr HKLM "${CHAVE_DESINSTALAR}" "QuietUninstallString" '"$INSTDIR\Desinstalar.exe" /S'
  WriteRegDWORD HKLM "${CHAVE_DESINSTALAR}" "NoModify" 1
  WriteRegDWORD HKLM "${CHAVE_DESINSTALAR}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $1 $2 $3
  WriteRegDWORD HKLM "${CHAVE_DESINSTALAR}" "EstimatedSize" $1

  ; 5. Serviço, firewall, config\updates, SudoVDA (só na instalação) e início.
  DetailPrint "Configurando o serviço e o firewall..."
  nsExec::ExecToLog '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configurar-host.ps1" -Pasta "$INSTDIR" $Atualizacao'
  Pop $0
  ${If} $0 != 0
    DetailPrint "configurar-host.ps1 falhou (código $0)."
    SetErrorLevel 1
    Abort "A configuração do Gabs Remote falhou (código $0)."
  ${EndIf}
  DetailPrint "Gabs Remote ${VERSION} instalado. Painel: https://localhost:47990"
SectionEnd

Function un.onInit
  SetRegView 64
  !insertmacro EscolherPowerShell
FunctionEnd

Section "Uninstall"
  SetShellVarContext all
  nsExec::ExecToLog '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\configurar-host.ps1" -Pasta "$INSTDIR" -Desinstalar'
  Pop $0

  ; Apaga tudo da pasta, menos config.
  FindFirst $1 $2 "$INSTDIR\*.*"
  ${DoWhile} $2 != ""
    ${If} $2 != "."
    ${AndIf} $2 != ".."
    ${AndIf} $2 != "config"
      ${If} ${FileExists} "$INSTDIR\$2\*.*"
        RMDir /r "$INSTDIR\$2"
      ${Else}
        Delete "$INSTDIR\$2"
      ${EndIf}
    ${EndIf}
    FindNext $1 $2
  ${Loop}
  FindClose $1

  DeleteRegKey HKLM "${CHAVE_DESINSTALAR}"
  DetailPrint "Gabs Remote removido. A configuração continua em $INSTDIR\config."
SectionEnd
