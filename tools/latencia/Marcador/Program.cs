namespace GabsRemote.Latencia;

internal static class Program
{
    /// <summary>
    /// Marcador do medidor de latência do Gabs Remote (docs/latencia.md).
    /// Uso: Marcador.exe [--monitor n]   (n começa em 1; padrão: o monitor principal)
    /// </summary>
    [STAThread]
    private static int Main(string[] args)
    {
        Screen tela = Screen.PrimaryScreen!;
        for (var i = 0; i < args.Length; i++)
        {
            if (args[i] == "--monitor" && i + 1 < args.Length && int.TryParse(args[i + 1], out var n))
            {
                var telas = Screen.AllScreens;
                if (n < 1 || n > telas.Length)
                {
                    MessageBox.Show($"Monitor {n} não existe (há {telas.Length}).", "Marcador");
                    return 1;
                }
                tela = telas[n - 1];
            }
        }

        ApplicationConfiguration.Initialize();
        var relogio = Relogio.Iniciar();
        using var udp = new RelogioUdp(relogio, RelogioUdp.Porta);
        udp.Iniciar();
        Application.Run(new MarcadorForm(relogio, tela));
        return 0;
    }
}
