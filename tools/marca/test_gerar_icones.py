import importlib.util
import json
from pathlib import Path

from PIL import Image

AQUI = Path(__file__).resolve().parent


def _carregar():
    spec = importlib.util.spec_from_file_location("gerar_icones", AQUI / "gerar-icones.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


gi = _carregar()
CORES = json.loads((AQUI / "cores.json").read_text(encoding="utf-8"))


def _rgb(hexa):
    hexa = hexa.lstrip("#")
    return tuple(int(hexa[i:i + 2], 16) for i in (0, 2, 4))


def test_tamanho():
    assert gi.desenhar_marca(192, CORES["claro"], True).size == (192, 192)


def test_fundo_azul_chapado_e_canto_reto():
    img = gi.desenhar_marca(192, CORES["claro"], True).convert("RGB")
    assert img.getpixel((2, 2)) == _rgb("#1b34f5")


def test_sem_suavizacao_so_quatro_cores():
    img = gi.desenhar_marca(192, CORES["claro"], True, suave=False).convert("RGB")
    cores = {c for _, c in img.getcolors(maxcolors=1_000_000)}
    esperadas = {_rgb(h) for h in ("#1b34f5", "#ffffff", "#e4f53a", "#0d0d0d")}
    assert cores == esperadas


def test_primeiro_plano_transparente():
    img = gi.desenhar_marca(432, CORES["claro"], False).convert("RGBA")
    assert img.getpixel((0, 0))[3] == 0


def test_gerar_android(tmp_path):
    gi.gerar(saida_android=tmp_path)
    assert Image.open(tmp_path / "mipmap-mdpi" / "ic_launcher.png").size == (48, 48)
    assert Image.open(tmp_path / "mipmap-xxxhdpi" / "ic_launcher.png").size == (192, 192)
    assert Image.open(tmp_path / "mipmap-xxxhdpi" / "ic_launcher_foreground.png").size == (432, 432)


def test_gerar_host_ico(tmp_path):
    gi.gerar(saida_host=tmp_path)
    ico = Image.open(tmp_path / "gabs-remote.ico")
    tamanhos = {s[0] for s in ico.info["sizes"]}
    assert {16, 24, 32, 48, 256} <= tamanhos
