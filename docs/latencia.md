# Medidor de latência

Mede o tempo entre uma ação e a imagem dela aparecer no tablet, com o app e um programa pequeno no PC (o **marcador**). Spec §9.3.

## O que cada modo mede

| Modo | Como funciona | O que mede |
|---|---|---|
| **Clique** | O app manda a tecla F24 pela sessão; o marcador alterna um quadrado preto/branco quando recebe a tecla; o app espera o quadrado mudar de cor na imagem. 40 amostras, uma a cada 400 ms, cada uma com até 1 s. | **Clique até a imagem**: rede de ida, injeção da tecla no Windows, desenho, captura, codificação, rede de volta, decodificação e exibição. É o número que o Gab sente. |
| **Carimbo** | O marcador desenha a hora dele (em ms) como um código de quadradinhos, a cada quadro do monitor. O app sincroniza o relógio com o marcador (20 pings UDP), lê o código em cada quadro por 10 s e compara com a própria hora. | **Captura até a exibição**: só a volta da imagem (captura, codificação, rede, decodificação). Inclui o tempo do `PixelCopy` que o app usa para ler o quadro (alguns ms), então o valor real é um pouco menor. |

## Como medir

1. No PC, abra o marcador (ele fica no canto superior esquerdo do monitor principal, por cima de tudo):
   ```
   C:\gr\tools\latencia\bin\Marcador.exe
   ```
   Com a tela virtual do tablet, o monitor principal durante a sessão é a própria tela virtual, então o padrão serve. Para outro monitor: `Marcador.exe --monitor 2` (a contagem começa em 1).
2. No tablet, abra a sessão, toque com **três dedos** para abrir o menu e escolha **Medir latência › Clique** ou **› Carimbo**.
3. No fim aparece um diálogo com média, p50, p95, máximo e perdidas.

Se o carimbo disser "Sem resposta do marcador", o marcador não está aberto ou a porta UDP 48100 está bloqueada (as regras `Gabs Remote LAN UDP` e `Gabs Remote Tailscale UDP` do `tools/setup/instalar-host.ps1` liberam essa porta).

## Onde ficam os resultados

Cada medição acrescenta linhas a `latencia-AAAAMMDD-HHmm.csv` na pasta do app no tablet (colunas `modo,amostra,ms`; amostra perdida fica com `ms` vazio). Para trazer ao PC:

```
adb pull /sdcard/Android/data/com.gabtavares.gabsremote/files/
```

(No build de debug a pasta é `com.gabtavares.gabsremote.debug`.)

## Contrato do carimbo (o mesmo nos dois lados)

- Janela de 192×80 px no canto superior esquerdo do monitor, sem borda, sempre por cima.
- **Carimbo** (x 0–127): grade de 8 colunas × 5 linhas, células de 16×16 px. Linha 0 = calibração (colunas pares brancas, ímpares pretas). Linhas 1–4 = os 32 bits de `t` (ms desde o início do marcador, `uint32`), do bit mais alto para o mais baixo, linha a linha; bit 1 = branco.
- **Quadrado do clique** (x 128–191, y 0–63): alterna preto/branco a cada F24 (`VK_F24 = 0x87`, pego por `RegisterHotKey`).
- **Relógio**: UDP 48100 no PC. Pedido de 1 byte `0x01`; resposta de 8 bytes, `int64` little-endian, com os mesmos ms de `t`.
- O app lê a luma média do miolo de cada célula; o carimbo só vale se branco − preto da calibração ≥ 64 (limiar = média das duas).

Código: `tools/latencia/Marcador/` (C#, .NET 8) e `android/app/src/main/java/com/limelight/gabs/latency/`. Testes: `dotnet test tools/latencia/Marcador.Tests` e `build-android.ps1 -Testes`.

## Gerar o marcador de novo

```
dotnet publish C:\gr\tools\latencia\Marcador -c Release -r win-x64 --self-contained false -o C:\gr\tools\latencia\bin
```

Precisa do .NET 8 Desktop Runtime no PC (já vem com o SDK 8 instalado).
