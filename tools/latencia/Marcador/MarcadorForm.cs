using System.Runtime.InteropServices;

namespace GabsRemote.Latencia;

/// <summary>
/// Janela de 192x80 px no canto superior esquerdo do monitor, sempre por cima e sem borda.
/// x 0-127: carimbo (8x5 células de 16 px). x 128-191, y 0-63: quadrado que alterna a cada F24.
/// O carimbo é redesenhado a cada quadro do monitor (DwmFlush).
/// </summary>
public sealed class MarcadorForm : Form
{
    private const int HotkeyId = 0x4752; // "GR"
    private const int VkF24 = 0x87;
    private const int WmHotkey = 0x0312;

    [DllImport("user32.dll")] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("dwmapi.dll")] private static extern int DwmFlush();

    private readonly Relogio _relogio;
    private volatile bool _rodando = true;
    private bool _quadradoBranco;

    public MarcadorForm(Relogio relogio, Screen tela)
    {
        _relogio = relogio;
        Text = "Gabs Remote — marcador de latência";
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = true;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        AutoScaleMode = AutoScaleMode.None;
        Bounds = new Rectangle(tela.Bounds.Left, tela.Bounds.Top, 192, 80);
        BackColor = Color.Black;
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        if (!RegisterHotKey(Handle, HotkeyId, 0, VkF24))
        {
            MessageBox.Show("Não foi possível registrar a tecla F24 (outro programa usa?). O modo Clique não vai funcionar.", "Marcador");
        }
        var laço = new Thread(() =>
        {
            while (_rodando)
            {
                if (DwmFlush() != 0)
                {
                    Thread.Sleep(4);
                }
                try
                {
                    BeginInvoke(Invalidate);
                }
                catch (InvalidOperationException)
                {
                    return;
                }
            }
        }) { IsBackground = true, Name = "Marcador.Quadros" };
        laço.Start();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WmHotkey && m.WParam.ToInt32() == HotkeyId)
        {
            _quadradoBranco = !_quadradoBranco;
            Invalidate();
        }
        base.WndProc(ref m);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.Clear(Color.Black);
        var celulas = StampCodec.Encode((uint)_relogio.AgoraMs);
        for (var i = 0; i < celulas.Length; i++)
        {
            if (!celulas[i])
            {
                continue;
            }
            var x = i % StampCodec.Columns * StampCodec.CellPx;
            var y = i / StampCodec.Columns * StampCodec.CellPx;
            g.FillRectangle(Brushes.White, x, y, StampCodec.CellPx, StampCodec.CellPx);
        }
        g.FillRectangle(_quadradoBranco ? Brushes.White : Brushes.Black, 128, 0, 64, 64);
        g.DrawRectangle(Pens.Gray, 128, 64, 63, 15);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _rodando = false;
        UnregisterHotKey(Handle, HotkeyId);
        base.OnFormClosed(e);
    }
}
