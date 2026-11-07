"""Gera os ícones do Gabs Remote (app Android e host) a partir de uma só função.

Uso:
    python tools/marca/gerar-icones.py --saida-android android/app/src/main/res
    python tools/marca/gerar-icones.py --saida-host <pasta>
    python tools/marca/gerar-icones.py --previa previa.png

Regras da marca: docs/marca/README.md (seção "Ícone"). Cores: tools/marca/cores.json.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

AQUI = Path(__file__).resolve().parent
FONTE = AQUI / "fontes" / "Archivo[wdth,wght].ttf"
CORES = AQUI / "cores.json"

TEXTO = ("G", "/", "R")
SOMBRA = 0.06  # deslocamento da sombra dura, fração do tamanho do ícone
SUPERAMOSTRA = 4  # desenha maior e reduz, para suavizar as bordas

# Tamanhos por densidade: ícone legado (48 dp) e primeiro plano adaptativo (108 dp).
DENSIDADES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}
TAMANHOS_ICO = (16, 24, 32, 48, 256)


def ler_cores(tema: str = "claro") -> dict:
    return json.loads(CORES.read_text(encoding="utf-8"))[tema]


def _rgb(hexa: str) -> tuple[int, int, int]:
    hexa = hexa.lstrip("#")
    return tuple(int(hexa[i:i + 2], 16) for i in (0, 2, 4))


def _fonte(px: int) -> ImageFont.FreeTypeFont:
    fonte = ImageFont.truetype(str(FONTE), px)
    # Estilo .cartaz do GAB/S: wdth 62, wght 900. A ordem dos eixos vem do arquivo
    # (neste Archivo é Weight, Width), então monta a lista pelo nome de cada eixo.
    alvo = {b"Weight": 900, b"Width": 62}
    fonte.set_variation_by_axes([alvo[e["name"]] for e in fonte.get_variation_axes()])
    return fonte


def _medir(fonte: ImageFont.FreeTypeFont) -> tuple[int, int, int, int]:
    """Caixa da marca inteira (sem sombra), relativa à origem do desenho."""
    img = Image.new("L", (1, 1))
    d = ImageDraw.Draw(img)
    return d.textbbox((0, 0), "".join(TEXTO), font=fonte)


def _desenhar_texto(d: ImageDraw.ImageDraw, origem, fonte, cores_por_letra) -> None:
    x, y = origem
    for letra, cor in zip(TEXTO, cores_por_letra):
        d.text((x, y), letra, font=fonte, fill=cor)
        x += fonte.getlength(letra)


def desenhar_marca(tamanho: int, cores: dict, com_fundo: bool, suave: bool = True) -> Image.Image:
    """Desenha o ícone quadrado: fundo azul chapado (opcional), G/R e sombra dura.

    com_fundo=True: ícone completo (legado, .ico, prévia); a marca ocupa ~76% da largura.
    com_fundo=False: primeiro plano do ícone adaptativo, transparente fora da marca; a marca
    (com a sombra) cabe no círculo de 66 dp dos 108 dp centrais.
    """
    escala = SUPERAMOSTRA if suave else 1
    lado = tamanho * escala
    fundo = (*_rgb(cores["azul"]), 255) if com_fundo else (0, 0, 0, 0)
    img = Image.new("RGBA", (lado, lado), fundo)
    d = ImageDraw.Draw(img)
    d.fontmode = "L" if suave else "1"

    sombra = round(lado * SOMBRA)
    # Ajusta o corpo da fonte para a caixa da marca + sombra caber na área útil.
    ref = 1000
    x0, y0, x1, y1 = _medir(_fonte(ref))
    larg_ref, alt_ref = x1 - x0, y1 - y0
    if com_fundo:
        fator = (lado * 0.76 - sombra) / larg_ref
    else:
        # diagonal da caixa (com sombra) <= 0,6 do lado (66 dp de 108 dp, com folga)
        diag_ref = (larg_ref ** 2 + alt_ref ** 2) ** 0.5
        fator = (lado * 0.60 - sombra * 1.4142) / diag_ref
    fonte = _fonte(max(1, int(ref * fator)))
    x0, y0, x1, y1 = _medir(fonte)
    larg, alt = x1 - x0, y1 - y0
    ox = (lado - (larg + sombra)) / 2 - x0
    oy = (lado - (alt + sombra)) / 2 - y0

    tinta = _rgb(cores["tinta"])
    branco = _rgb(cores["sobre_azul"])
    acido = _rgb(cores["acido"])
    _desenhar_texto(d, (ox + sombra, oy + sombra), fonte, (tinta, tinta, tinta))
    _desenhar_texto(d, (ox, oy), fonte, (branco, acido, branco))

    if escala != 1:
        img = img.resize((tamanho, tamanho), Image.Resampling.LANCZOS)
    if com_fundo:
        # Garante o fundo chapado e opaco (o LANCZOS pode deixar alfa < 255 na borda).
        base = Image.new("RGBA", img.size, (*_rgb(cores["azul"]), 255))
        base.alpha_composite(img)
        img = base
    return img


def _salvar_png(img: Image.Image, caminho: Path) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    img.save(caminho, optimize=True)


def _salvar_ico(caminho: Path, cores: dict, tamanhos=TAMANHOS_ICO) -> None:
    imagens = [desenhar_marca(t, cores, True) for t in tamanhos]
    maior = imagens[-1]
    maior.save(caminho, format="ICO", sizes=[(t, t) for t in tamanhos], append_images=imagens[:-1])


def gerar(saida_android: Path | None = None, saida_host: Path | None = None) -> None:
    cores = ler_cores("claro")
    if saida_android is not None:
        saida_android = Path(saida_android)
        for dens, f in DENSIDADES.items():
            pasta = saida_android / f"mipmap-{dens}"
            _salvar_png(desenhar_marca(round(48 * f), cores, True), pasta / "ic_launcher.png")
            _salvar_png(desenhar_marca(round(108 * f), cores, False), pasta / "ic_launcher_foreground.png")
        _salvar_png(desenhar_marca(96, cores, True), saida_android / "drawable" / "app_icon.png")
    if saida_host is not None:
        saida_host = Path(saida_host)
        saida_host.mkdir(parents=True, exist_ok=True)
        _salvar_ico(saida_host / "gabs-remote.ico", cores)
        _salvar_png(desenhar_marca(256, cores, True), saida_host / "gabs-remote-256.png")
        _salvar_ico(saida_host / "favicon.ico", cores, (16, 32, 48))


def main() -> None:
    p = argparse.ArgumentParser(description="Gera os ícones do Gabs Remote.")
    p.add_argument("--saida-android", type=Path, help="pasta res/ do app")
    p.add_argument("--saida-host", type=Path, help="pasta onde gravar .ico e .png do host")
    p.add_argument("--previa", type=Path, help="grava uma prévia PNG 512")
    a = p.parse_args()
    if a.previa:
        _salvar_png(desenhar_marca(512, ler_cores("claro"), True), a.previa)
    gerar(a.saida_android, a.saida_host)


if __name__ == "__main__":
    main()
