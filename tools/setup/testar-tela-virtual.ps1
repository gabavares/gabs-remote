<#
.SYNOPSIS
    Cria um monitor virtual de teste pelo driver SudoVDA, mostra a resolução e a taxa que o
    Windows aplicou, espera e remove.
.DESCRIPTION
    Usa a mesma API (IOCTL) que o host usa (decisão 0003). Não precisa de administrador: o INF do
    driver dá leitura e escrita no dispositivo a todos os usuários. Enquanto o script roda, ele
    "pinga" o driver; se o script morrer, o watchdog do driver remove o monitor sozinho.
.PARAMETER Largura
    Largura em pixels (padrão 2800, o Tab S10+ em paisagem).
.PARAMETER Altura
    Altura em pixels (padrão 1752).
.PARAMETER Hz
    Taxa de atualização em Hz (padrão 120). O driver recebe em milésimos de Hz.
.PARAMETER Segundos
    Quanto tempo o monitor fica ativo antes de ser removido (padrão 20).
.EXAMPLE
    powershell -File C:\gr\tools\setup\testar-tela-virtual.ps1 -Segundos 30
#>
[CmdletBinding()]
param(
    [int]$Largura = 2800,
    [int]$Altura = 1752,
    [int]$Hz = 120,
    [int]$Segundos = 20
)
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class SudoVda {
    static readonly Guid InterfaceGuid = new Guid("e5bcc234-1e0c-418a-a0d4-ef8b7501414d");
    const uint DIGCF_PRESENT = 0x2, DIGCF_DEVICEINTERFACE = 0x10;
    static uint Ctl(uint fn) { return (0x22u << 16) | (fn << 2); } // FILE_DEVICE_UNKNOWN, METHOD_BUFFERED, FILE_ANY_ACCESS
    public static readonly uint IOCTL_ADD = Ctl(0x800), IOCTL_REMOVE = Ctl(0x801),
        IOCTL_GET_WATCHDOG = Ctl(0x803), IOCTL_PING = Ctl(0x888), IOCTL_VERSION = Ctl(0x8FF);

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid InterfaceClassGuid; public int Flags; public IntPtr Reserved; }

    [DllImport("setupapi.dll", SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr h, uint flags);
    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr set, IntPtr info, ref Guid g, uint idx, ref SP_DEVICE_INTERFACE_DATA data);
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr set, ref SP_DEVICE_INTERFACE_DATA data, IntPtr detail, int size, out int req, IntPtr info);
    [DllImport("setupapi.dll")]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr set);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(SafeFileHandle h, uint code, byte[] inBuf, int inSize, byte[] outBuf, int outSize, out int ret, IntPtr ov);

    public static SafeFileHandle Open() {
        Guid g = InterfaceGuid;
        IntPtr set = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        try {
            var data = new SP_DEVICE_INTERFACE_DATA();
            data.cbSize = Marshal.SizeOf(typeof(SP_DEVICE_INTERFACE_DATA));
            for (uint i = 0; SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref data); i++) {
                int req;
                SetupDiGetDeviceInterfaceDetail(set, ref data, IntPtr.Zero, 0, out req, IntPtr.Zero);
                IntPtr buf = Marshal.AllocHGlobal(req);
                try {
                    Marshal.WriteInt32(buf, IntPtr.Size == 8 ? 8 : 6); // cbSize de SP_DEVICE_INTERFACE_DETAIL_DATA_W
                    if (!SetupDiGetDeviceInterfaceDetail(set, ref data, buf, req, out req, IntPtr.Zero)) continue;
                    string path = Marshal.PtrToStringUni(new IntPtr(buf.ToInt64() + 4));
                    var h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
                    if (!h.IsInvalid) return h;
                } finally { Marshal.FreeHGlobal(buf); }
            }
        } finally { SetupDiDestroyDeviceInfoList(set); }
        return null;
    }

    static byte[] Call(SafeFileHandle h, uint code, byte[] input, int outSize) {
        byte[] output = new byte[outSize];
        int ret;
        if (!DeviceIoControl(h, code, input, input == null ? 0 : input.Length, output, outSize, out ret, IntPtr.Zero))
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        return output;
    }

    public static string Version(SafeFileHandle h) {
        byte[] v = Call(h, IOCTL_VERSION, null, 4);
        return v[0] + "." + v[1] + "." + v[2] + (v[3] != 0 ? " (teste)" : "");
    }

    public static uint WatchdogSeconds(SafeFileHandle h) { return BitConverter.ToUInt32(Call(h, IOCTL_GET_WATCHDOG, null, 8), 0); }

    public static void Ping(SafeFileHandle h) { Call(h, IOCTL_PING, null, 0); }

    // VIRTUAL_DISPLAY_ADD_PARAMS: UINT Width, Height, RefreshRate (mHz); GUID; CHAR DeviceName[14]; CHAR SerialNumber[14]
    public static uint Add(SafeFileHandle h, uint w, uint hgt, uint milliHz, Guid monitor, string name, string serial) {
        var ms = new MemoryStream();
        var bw = new BinaryWriter(ms);
        bw.Write(w); bw.Write(hgt); bw.Write(milliHz); bw.Write(monitor.ToByteArray());
        bw.Write(Fixed(name)); bw.Write(Fixed(serial));
        byte[] outBuf = Call(h, IOCTL_ADD, ms.ToArray(), 12); // LUID AdapterLuid (8) + UINT TargetId
        return BitConverter.ToUInt32(outBuf, 8);
    }

    public static void Remove(SafeFileHandle h, Guid monitor) { Call(h, IOCTL_REMOVE, monitor.ToByteArray(), 0); }

    static byte[] Fixed(string s) {
        byte[] b = new byte[14];
        byte[] src = Encoding.ASCII.GetBytes(s);
        Array.Copy(src, b, Math.Min(13, src.Length));
        return b;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
        public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
        public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels; public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);

    public static string CurrentMode(string gdiName) {
        var dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
        if (!EnumDisplaySettings(gdiName, -1, ref dm)) return null; // ENUM_CURRENT_SETTINGS
        return dm.dmPelsWidth + "x" + dm.dmPelsHeight + " @ " + dm.dmDisplayFrequency + " Hz";
    }
}
'@

# Telas ativas agora (sem cache): as saídas \\.\DISPLAYn com modo atual definido.
function Get-Telas { 1..32 | ForEach-Object { "\\.\DISPLAY$_" } | Where-Object { [SudoVda]::CurrentMode($_) } }

$h = [SudoVda]::Open()
if (-not $h) {
    Write-Host 'ERRO: driver SudoVDA não encontrado (instale com drivers\sudovda\install.bat como administrador).' -ForegroundColor Red
    exit 1
}
Write-Host "SudoVDA: protocolo $([SudoVda]::Version($h)), watchdog $([SudoVda]::WatchdogSeconds($h)) s"

$antes = @(Get-Telas)
$guid = [guid]::NewGuid()
$target = [SudoVda]::Add($h, $Largura, $Altura, $Hz * 1000, $guid, 'GabsTeste', 'GABS0001')
Write-Host "Monitor criado (target id $target). Esperando o Windows ativar..."
$nova = $null
for ($i = 0; $i -lt 30 -and -not $nova; $i++) {
    Start-Sleep -Milliseconds 200
    [SudoVda]::Ping($h)
    $nova = Get-Telas | Where-Object { $antes -notcontains $_ } | Select-Object -First 1
}
if ($nova) {
    Write-Host "OK: $nova em $([SudoVda]::CurrentMode($nova)) (pedido: ${Largura}x$Altura @ $Hz Hz)" -ForegroundColor Green
} else {
    Write-Host 'AVISO: o Windows não listou um monitor novo em 6 s.' -ForegroundColor Yellow
}
Write-Host "Confira em Configurações > Sistema > Tela. Removendo em $Segundos s..."
$fim = (Get-Date).AddSeconds($Segundos)
while ((Get-Date) -lt $fim) { [SudoVda]::Ping($h); Start-Sleep -Seconds 1 }
[SudoVda]::Remove($h, $guid)
$h.Dispose()
Write-Host 'Monitor removido.'
exit 0
