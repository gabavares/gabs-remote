using GabsRemote.Latencia;
using Xunit;

namespace GabsRemote.Latencia.Tests;

public class StampCodecTests
{
    private static string Bits(bool[] cells, int start, int count) =>
        new string(cells.Skip(start).Take(count).Select(b => b ? '1' : '0').ToArray());

    [Fact]
    public void CalibracaoAlternaBrancoEPreto()
    {
        var cells = StampCodec.Encode(0x89ABCDEF);
        Assert.Equal(40, cells.Length);
        Assert.Equal("10101010", Bits(cells, 0, 8));
    }

    [Fact]
    public void DadosDoBitMaisAltoParaOMaisBaixo()
    {
        var cells = StampCodec.Encode(0x89ABCDEF);
        Assert.Equal("10001001" + "10101011" + "11001101" + "11101111", Bits(cells, 8, 32));
    }

    [Fact]
    public void ZeroTemDadosPretos()
    {
        var cells = StampCodec.Encode(0);
        Assert.Equal(new string('0', 32), Bits(cells, 8, 32));
        Assert.Equal("10101010", Bits(cells, 0, 8));
    }
}

public class RelogioUdpTests
{
    [Fact]
    public void RespostaEmInt64LittleEndian()
    {
        var b = RelogioUdp.Resposta(0x0102030405060708);
        Assert.Equal(new byte[] { 8, 7, 6, 5, 4, 3, 2, 1 }, b);
    }
}

public class RelogioUdpRedeTests
{
    [Fact]
    public async Task RespondeAoPingPorIPv4()
    {
        // O tablet pinga por IPv4 (LAN 192.168.x ou Tailscale 100.x).
        var porta = 48000 + Random.Shared.Next(200, 900);
        var relogio = Relogio.Iniciar();
        using var servidor = new RelogioUdp(relogio, porta);
        servidor.Iniciar();

        using var cliente = new System.Net.Sockets.UdpClient(System.Net.Sockets.AddressFamily.InterNetwork);
        await cliente.SendAsync(new byte[] { 0x01 }, 1, new System.Net.IPEndPoint(System.Net.IPAddress.Loopback, porta));
        var recebe = cliente.ReceiveAsync();
        var venceu = await Task.WhenAny(recebe, Task.Delay(2000));
        Assert.Same(recebe, venceu);
        Assert.Equal(8, recebe.Result.Buffer.Length);
    }
}
