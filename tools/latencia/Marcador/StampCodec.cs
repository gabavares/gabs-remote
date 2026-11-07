namespace GabsRemote.Latencia;

/// <summary>
/// Carimbo de tempo desenhado na tela do PC e lido pelo app (contrato em docs/latencia.md).
/// Grade de 8 colunas x 5 linhas: linha 0 = calibração (colunas pares brancas, ímpares pretas);
/// linhas 1 a 4 = os 32 bits de t, do mais alto para o mais baixo; bit 1 = branco.
/// </summary>
public static class StampCodec
{
    public const int Columns = 8;
    public const int Rows = 5;
    public const int CellPx = 16;

    /// <summary>40 células na ordem de leitura (linha a linha); true = branco.</summary>
    public static bool[] Encode(uint t)
    {
        var cells = new bool[Columns * Rows];
        for (var c = 0; c < Columns; c++)
        {
            cells[c] = c % 2 == 0;
        }
        for (var bit = 0; bit < 32; bit++)
        {
            cells[Columns + bit] = ((t >> (31 - bit)) & 1) == 1;
        }
        return cells;
    }
}
