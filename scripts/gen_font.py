"""Bugle Sans and Bugle Display: Inter and Inter Tight (The Inter Project Authors, SIL Open Font License 1.1, no
reserved name), renamed.

Inter is drawn for screens in the Helvetica and San Francisco line: a neutral sans serif with open shapes, real
lowercase and proportional spacing. Sans for reading, Inter Tight Bold for headlines. Same method as Hermes Sans and
Talli Display: pinned release, renamed, OFL shipped beside the fonts, original copyright kept in the name table.
Latin only, web only for now (the apps use SF itself), every build the same bytes.

    uv run --with fonttools --with brotli python3 scripts/gen_font.py           # web/fonts/*.woff2 + OFL.txt
    uv run --with fonttools --with brotli python3 scripts/gen_font.py --check   # named Bugle, OFL present
"""
import io
import os
import sys
import urllib.request

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(HERE, "web", "fonts")
CDN = "https://cdn.jsdelivr.net/npm/@fontsource/"
OFL = ["https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt",
       "https://raw.githubusercontent.com/google/fonts/main/ofl/intertight/OFL.txt"]
# family, style, weight, source file
FACES = [
    ("Bugle Sans", "Regular", 400, "inter@5.2.5/files/inter-latin-400-normal.woff2"),
    ("Bugle Sans", "Medium", 500, "inter@5.2.5/files/inter-latin-500-normal.woff2"),
    ("Bugle Sans", "Semibold", 600, "inter@5.2.5/files/inter-latin-600-normal.woff2"),
    ("Bugle Sans", "Bold", 700, "inter@5.2.5/files/inter-latin-700-normal.woff2"),
    ("Bugle Display", "Bold", 700, "inter-tight@5.2.5/files/inter-tight-latin-700-normal.woff2"),
]


def fetch(url):
    """Bytes of one pinned file."""
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def file_name(family, style):
    return family.replace(" ", "") + "-" + style


def rename(font, family, style):
    """Give the outlines the Bugle name; copyright (0) and license (13, 14) stay as the authors wrote them."""
    ps = file_name(family, style)
    names = {1: family, 2: style, 3: ps, 4: f"{family} {style}", 5: "Version 1.000", 6: ps, 16: family, 17: style}
    table = font["name"]
    table.names = [n for n in table.names if n.nameID in (0, 13, 14)]
    for nid, text in names.items():
        table.setName(text, nid, 3, 1, 0x409)
        table.setName(text, nid, 1, 0, 0)
    font["head"].created = font["head"].modified = 3_700_000_000   # fixed, so every build is the same bytes
    font["OS/2"].achVendID = "CRNT"


def check():
    """Self-check of the shipped files."""
    assert os.path.exists(os.path.join(WEB, "OFL.txt")), "the OFL must ship with the fonts"
    assert "Inter Project Authors" in open(os.path.join(WEB, "OFL.txt")).read(), "OFL must carry the Inter copyright"
    for family, style, _, _ in FACES:
        f = TTFont(os.path.join(WEB, file_name(family, style) + ".woff2"))
        assert f["name"].getDebugName(1) == family and f["name"].getDebugName(6) == file_name(family, style)
        assert "Inter" in f["name"].getDebugName(0), "original copyright must stay in the name table"
        assert f.getBestCmap().get(ord("a")), "lowercase must be present"
        cmap, hm = f.getBestCmap(), f["hmtx"]
        assert len({hm[cmap[ord(d)]][0] for d in "0123456789"}) > 1, f"{family} {style} digits must be proportional"
    print("font ok: Bugle Sans and Bugle Display (Inter and Inter Tight, OFL)")


def main():
    """Fetch Inter, rename it, write the web files and the license."""
    if "--check" in sys.argv:
        return check()
    os.makedirs(WEB, exist_ok=True)
    for family, style, _, src in FACES:
        font = TTFont(io.BytesIO(fetch(CDN + src)))
        rename(font, family, style)
        font.flavor = "woff2"
        font.save(os.path.join(WEB, file_name(family, style) + ".woff2"), reorderTables=False)
        print(file_name(family, style))
    with open(os.path.join(WEB, "OFL.txt"), "wb") as f:
        f.write(b"\n\n".join(fetch(u) for u in OFL))


if __name__ == "__main__":
    main()
