using System.Diagnostics;

namespace GabsRemote.Latencia;

/// <summary>Milissegundos desde o início do marcador (o mesmo relógio do carimbo e do UDP).</summary>
public sealed class Relogio
{
    private readonly Stopwatch _sw;

    private Relogio(Stopwatch sw) => _sw = sw;

    public static Relogio Iniciar() => new(Stopwatch.StartNew());

    public long AgoraMs => _sw.ElapsedMilliseconds;
}
