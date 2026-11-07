# Identidade visual do Gabs Remote

O Gabs Remote segue o **design system GAB/S**, o mesmo do Sistema de Criação do Gab: um cartaz neo-brutalista impresso em papel de jornal, com cor chapada que tem significado, bordas de 2px e sombra dura sem desfoque.

- **Fonte da verdade:** `C:\Users\Gabriel\Desktop\Gabtavares.com\gabs-design-system\` (fora deste repositório).
- **Cópia de referência:** [`gabs-design-system/DESIGN.md`](gabs-design-system/DESIGN.md) e [`gabs-design-system/tokens.css`](gabs-design-system/tokens.css), copiados em 07/11/2026. Se o original mudar, copie de novo e atualize `tools/marca/cores.json`.
- **Exemplo de uso:** [`referencia-gabs.webp`](referencia-gabs.webp), uma edição do Sistema de Criação: título em `--tinta` com sombra `--acido`, título em `--azul` com sombra `--tinta`, papel creme pontilhado, campos chapados azul e laranja com texto branco ou preto.

## Tokens usados

`tools/marca/cores.json` guarda os tokens abaixo (criado na Task 2 do plano da fase 2). É a única fonte das cores no código: o script de ícones, o tema do app e o painel do host leem dele.

| Token | Claro | Escuro | Onde entra no Gabs Remote |
|---|---|---|---|
| `--azul` | `#1b34f5` | `#2a45ff` | fundo do ícone, cor de ação e foco (app e painel) |
| `--acido` | `#e4f53a` | `#dcf02c` | a barra `/` do ícone, destaque e seleção |
| `--laranja` | `#ff3b1d` | `#ff5533` | só erro e urgência (ex.: falha de conexão) |
| `--tinta` | `#0d0d0d` | `#f1efe9` | texto, bordas e sombra dura |
| `--papel` | `#f1efe9` | `#000000` | fundo das telas |
| `--folha` | `#fbfaf7` | `#0c0c0c` | cartões e campos |
| `--sobre-azul` | `#ffffff` | `#ffffff` | letras do ícone e todo texto sobre o azul |

O app do upstream usa tema escuro, então o app pega a coluna **Escuro**. O ícone e o painel web do host usam a coluna **Claro**.

Regras que valem já na fase 2 (`--sobre-azul`, `--sobre-laranja`, `--sobre-acido`): texto **branco no azul** e **preto no laranja e no ácido**; cada cor só no seu papel; nada de degradê, sombra desfocada ou canto arredondado (exceto onde o Android recorta o ícone).

## Ícone

- **Fundo:** `--azul` (`#1b34f5`) chapado.
- **Marca:** o monograma **`G/R`** no estilo `.cartaz` do GAB/S: Archivo com `wdth` 62 e `wght` 900, caixa alta. O "G" e o "R" ficam em `--sobre-azul` (`#ffffff`) e a barra `/` em `--acido` (`#e4f53a`), como a barra do logo `GAB/S`.
- **Sombra dura:** a marca inteira com cópia deslocada para a direita e para baixo em 6% do tamanho do ícone, na cor `--tinta` (`#0d0d0d`), sem desfoque (equivale a `3px 3px 0` num ícone de 48 px).
- **Cantos retos.** No Android o sistema recorta o ícone adaptativo; o arquivo em si é quadrado. O `.ico` do host também é quadrado.
- **Fonte:** Archivo (Google Fonts, licença OFL), guardada em `tools/marca/fontes/` com o `OFL.txt`.

## O que fica para a fase 7
Layout próprio das telas (lista de PCs, configurações, barra da sessão), tipografia Archivo/Space Grotesk no app, papel creme pontilhado, cartões com borda e sombra dura. Na fase 2 só entram nome, ícone e cores.
