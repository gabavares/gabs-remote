# GAB/S — Design System

Cartaz neo-brutalista impresso em papel de jornal. A cor aparece em campos chapados e cada uma tem
um significado. A profundidade vem de sobreposição e sombra dura, nunca de desfoque.
Os tokens prontos estão em `tokens.css`.

## Princípios
1. **Papel e tinta.** O fundo é creme (`--papel`), os cartões são um tom mais claros (`--folha`) e
   o texto é quase preto. A interface se lê como uma página impressa.
2. **Cor tem significado.** Laranja é urgente. Azul é ação e prazo próximo. Ácido é destaque ou
   item sem prazo. Use cada cor só no seu papel e nunca como fundo da página.
3. **Bordas e sombras duras.** Bordas de 2px na cor da tinta, sombra deslocada `3px 3px 0` sem
   desfoque e cantos retos. Pílulas e círculos só em controles como chaves e bolinhas.
4. **Composição de cartaz.** Títulos grandes, condensados e em caixa alta. Painéis podem vazar e se
   sobrepor, e carimbos podem ficar por cima.

## Cores

| Token | Claro | Escuro | Uso |
|---|---|---|---|
| `--papel` | `#f1efe9` | `#000000` | fundo da página |
| `--folha` | `#fbfaf7` | `#0c0c0c` | painéis, cartões, campos |
| `--tinta` | `#0d0d0d` | `#f1efe9` | texto principal |
| `--tinta-2` | `#3a3a37` | `#c6c4bd` | texto secundário |
| `--tinta-3` | `#5a5a56` | `#9c9a94` | rótulos, placeholders |
| `--fio` / `--sombra` | `#0d0d0d` | `#f1efe9` | bordas e sombra dura |
| `--fio-fraco` | `#cfccc3` | `#2b2b2b` | divisórias discretas |
| `--azul` | `#1b34f5` | `#2a45ff` | ação, prazo próximo, foco |
| `--azul-texto` | `#1b34f5` | `#97a6ff` | azul usado como texto |
| `--laranja` | `#ff3b1d` | `#ff5533` | urgente, asterisco |
| `--laranja-texto` | `#c42a0e` | `#ff8b6d` | laranja usado como texto (contraste) |
| `--acido` | `#e4f53a` | `#dcf02c` | destaque, seleção, sem prazo |

Texto sobre as cores de destaque: **branco no azul** e **preto no laranja e no ácido**.
Para texto colorido, use as variantes `-texto`, porque as cores chapadas não têm contraste
suficiente para isso.

## Tipografia
- **Archivo**, com largura variável de 62 a 125 e pesos de 400 a 900. É a voz grotesca dos títulos.
  - `.cartaz`: `font-stretch:62%`, peso 900, caixa alta, `line-height:.86`, `letter-spacing:-.01em`.
    Serve para manchetes enormes e números de destaque.
  - `.titulo-largo`: `font-stretch:108%`, peso 900, caixa alta, `line-height:.92`. Serve para
    títulos de seção e logotipo.
- **Space Grotesk**, nos pesos 400 a 700, para o texto corrido. Base de 16px com `line-height:1.5`
  e números tabulares.
- `.rotulo`: Space Grotesk 500, 11,5px, caixa alta, `letter-spacing:.16em`. Serve para metadados,
  datas e etiquetas.
- Manchetes de bloco: Space Grotesk 800, `clamp(20px,1.6vw,25px)`, no máximo `36ch` e
  `text-wrap:balance`.

## Forma
- Borda: `2px solid var(--fio)`.
- Sombra: `3px 3px 0 var(--sombra)`. Em painéis grandes, `6px 6px 0`.
- Raio: `0`. A exceção são as chaves de tema, que levam `999px`.
- Gutter lateral: `clamp(16px,3vw,44px)`.
- Marcador de seção (`.marco`): um número ou rótulo seguido de um fio de 1px que ocupa o resto da
  linha.
- Detalhes gráficos: cruzes de registro de 15px com traço de 1px, como marca de corte, e asterisco
  laranja como sinal de urgência.

## Interação e movimento
- Easing único: `--sai: cubic-bezier(.16,1,.3,1)`. Use .2s em hover e .3s em mudança de tema.
- Botão: no hover sobe 1px e a sombra cresce. No clique afunda 3px e a sombra some, como se o
  botão fosse carimbado.
- Foco: `outline: 3px solid var(--azul)` com `outline-offset: 3px`.
- Seleção de texto: fundo ácido com texto preto.
- Barra de rolagem: polegar na cor da tinta com borda de 3px na cor do papel.
- Cursor (opcional): mira em forma de cruz com um círculo azul.

## Ícones
Desenhados em SVG no tamanho `1em`, com `stroke: currentColor`, `stroke-width: 2.2`,
`stroke-linecap: square` e sem preenchimento.

## Tema escuro
Ative com `<html data-tema="escuro">`. O papel fica preto, a tinta fica creme, as bordas e sombras
ficam creme e as cores de destaque ficam um pouco mais claras.

## O que evitar
Degradês, sombras desfocadas, cantos arredondados em cartões, cinzas frios, mais de uma cor de
destaque no mesmo elemento e cor usada só como decoração.
