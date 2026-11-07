using System.Net;
using System.Net.Sockets;

namespace GabsRemote.Latencia;

/// <summary>
/// Responde ao ping do app: pedido de 1 byte 0x01, resposta de 8 bytes (int64 little-endian)
/// com a hora do marcador em ms. Porta UDP 48100.
/// </summary>
public sealed class RelogioUdp : IDisposable
{
    public const int Porta = 48100;

    private readonly Relogio _relogio;
    private readonly UdpClient _udp;
    private readonly CancellationTokenSource _cts = new();

    public RelogioUdp(Relogio relogio, int porta)
    {
        _relogio = relogio;
        _udp = new UdpClient(new IPEndPoint(IPAddress.IPv6Any, porta));
        _udp.Client.DualMode = true;
    }

    public void Iniciar() => _ = Task.Run(LaçoAsync);

    public static byte[] Resposta(long agoraMs) => BitConverter.IsLittleEndian
        ? BitConverter.GetBytes(agoraMs)
        : BitConverter.GetBytes(agoraMs).Reverse().ToArray();

    private async Task LaçoAsync()
    {
        while (!_cts.IsCancellationRequested)
        {
            UdpReceiveResult r;
            try
            {
                r = await _udp.ReceiveAsync(_cts.Token);
            }
            catch (OperationCanceledException)
            {
                return;
            }
            catch (SocketException)
            {
                continue;
            }
            if (r.Buffer.Length == 1 && r.Buffer[0] == 0x01)
            {
                var resposta = Resposta(_relogio.AgoraMs);
                await _udp.SendAsync(resposta, resposta.Length, r.RemoteEndPoint);
            }
        }
    }

    public void Dispose()
    {
        _cts.Cancel();
        _udp.Dispose();
    }
}
