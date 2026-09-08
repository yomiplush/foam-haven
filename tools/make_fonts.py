"""Build per-language UI font subsets from the installed Noto Sans CJK.

Each language gets its own TTF subset so the right regional glyph shapes
are used (ja/en/ru from the JP face, ko from KR, zh-hans from SC, zh-hant
from TC). Glyph set = that language's UI strings + the shared ASCII set,
so the file stays small while every on-screen message has coverage.

Usage:
    python3 tools/make_fonts.py
"""
from pathlib import Path
import json
from fontTools.ttLib import TTFont
from fontTools import subset

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
FONT_TTC = "/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc"
# Noto Sans CJK JP also carries Latin and Cyrillic, so en/ru reuse it.
FACES = {"ja": 0, "en": 0, "ru": 0, "ko": 1, "zh_hans": 2, "zh_hant": 3}
LANGS = ["ja", "en", "zh_hans", "zh_hant", "ko", "ru"]

# ASCII plus punctuation/digits used across all six UI languages.
BASE = ("abcdefghijklmnopqrstuvwxyz"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "0123456789"
        " 　.,:;!?()[]/-_+*=@#$%&'\"|\\<>^`~…·→←■□●○・〜％　"
        "\n")


def char_text():
    data = json.loads((ASSETS / "i18n.json").read_text(encoding="utf-8"))
    per_lang = {lang: "" for lang in LANGS}
    for entry in data.values():
        for lang in LANGS:
            per_lang[lang] += entry[lang]
    return per_lang


def make_fonts():
    texts = char_text()
    out_dir = ASSETS / "fonts"
    out_dir.mkdir(exist_ok=True)
    for lang in LANGS:
        text = BASE + texts[lang]
        font = TTFont(FONT_TTC, fontNumber=FACES[lang])
        sub = subset.Subsetter(options=subset.Options())
        sub.populate(text=text)
        sub.subset(font)
        path = out_dir / f"ui_{lang}.ttf"
        font.save(str(path))
        print("generated", path.name)


if __name__ == "__main__":
    make_fonts()
