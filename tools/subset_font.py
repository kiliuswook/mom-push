#!/usr/bin/env python3
"""웹 빌드용 한글 폰트 서브셋.

NotoSansKR 원본은 10MB 다. UI 문자열은 전부 .gd 소스 안에 있으므로
실제로 쓰이는 글자만 남기면 웹 다운로드가 크게 줄어든다.

    python tools/subset_font.py

새 글자가 들어간 문자열을 추가했다면 다시 돌려야 한다.
원본은 assets/fonts/NotoSansKR-full.ttf 로 보관한다.
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FULL = ROOT / "assets" / "fonts" / "NotoSansKR-full.ttf"
OUT = ROOT / "assets" / "fonts" / "NotoSansKR.ttf"

# 소스에 없더라도 런타임에 나올 수 있는 글자들.
EXTRA = (
    "0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    r""" !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"""
    "…·—–‘’“”×✕→←↑↓◆●○■□▲△★☆°％"
)

chars = set(EXTRA)
scanned = 0
for path in list(ROOT.glob("**/*.gd")) + list(ROOT.glob("**/*.tscn")):
    if ".godot" in path.parts or "build" in path.parts:
        continue
    chars.update(path.read_text(encoding="utf-8"))
    scanned += 1

# 제어 문자 제거
chars = {c for c in chars if c.isprintable() and c != " " or c == " "}
text = "".join(sorted(chars))

SOURCE_URL = (
    "https://github.com/google/fonts/raw/main/ofl/notosanskr/NotoSansKR%5Bwght%5D.ttf"
)

if not FULL.exists():
    # 원본은 저장소에 넣지 않는다 (10MB). 필요할 때만 내려받는다.
    import urllib.request

    print("원본 폰트 내려받는 중: %s" % SOURCE_URL)
    FULL.parent.mkdir(parents=True, exist_ok=True)
    urllib.request.urlretrieve(SOURCE_URL, FULL)

subprocess.run(
    [
        sys.executable, "-m", "fontTools.subset", str(FULL),
        "--text=%s" % text,
        "--output-file=%s" % OUT,
        "--layout-features=*",
        "--drop-tables+=DSIG",
        "--no-hinting",
    ],
    check=True,
)
print("소스 %d개 스캔 / 글자 %d자 / %.2fMB -> %.2fMB" % (
    scanned, len(chars), FULL.stat().st_size / 1e6, OUT.stat().st_size / 1e6
))
