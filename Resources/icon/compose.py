#!/usr/bin/env python3
"""source.svg（512x512 のイラスト）から macOS アイコン用の 1024x1024 SVG を組み立てる。

Big Sur 以降のアイコンは「角丸スクエア（スーパー楕円）の中に絵を置く」形なので、
背景のスクイルクルを描いてから、イラストを Apple のアイコングリッドに合わせて
中央へ縮小配置する。イラスト側の座標系は 512x512、余白の実測値は BBOX。
"""

import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE / "source.svg"
OUT = HERE / "AppIcon.svg"

SIZE = 1024
# Apple のアイコングリッド: 1024 のうち角丸スクエアは 824（左右に 100 の余白）
PLATE = 824
PLATE_INSET = (SIZE - PLATE) / 2
# スクイルクル内でイラストが占める領域（さらに内側に余白を取る）
ART_BOX = 604
# source.svg の実効バウンディングボックス（512 座標系での実測）
BBOX = (30.0, 0.0, 478.0, 508.0)


def squircle_path(cx: float, cy: float, half: float, n: float = 5.0, steps: int = 720) -> str:
    """スーパー楕円 |x|^n + |y|^n = 1 で Apple 風の連続的な角丸を近似する。"""
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        ct, st = math.cos(t), math.sin(t)
        x = math.copysign(abs(ct) ** (2 / n), ct)
        y = math.copysign(abs(st) ** (2 / n), st)
        pts.append(f"{cx + x * half:.3f},{cy + y * half:.3f}")
    return "M" + "L".join(pts) + "Z"


def inner_svg(text: str) -> str:
    """<svg> ルート要素を剥がして中身だけ返す。"""
    start = text.index(">", text.index("<svg")) + 1
    end = text.rindex("</svg>")
    return text[start:end]


def main() -> int:
    art = inner_svg(SRC.read_text(encoding="utf-8"))

    x0, y0, x1, y1 = BBOX
    scale = ART_BOX / max(x1 - x0, y1 - y0)
    # bbox の中心をキャンバス中心に合わせる
    tx = SIZE / 2 - (x0 + x1) / 2 * scale
    ty = SIZE / 2 - (y0 + y1) / 2 * scale

    plate = squircle_path(SIZE / 2, SIZE / 2, PLATE / 2)

    OUT.write_text(
        f'''<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">
  <defs>
    <linearGradient id="plate" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#f5f9ff"/>
      <stop offset="1" stop-color="#c6daf2"/>
    </linearGradient>
    <filter id="plateShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#0d2440" flood-opacity="0.22"/>
    </filter>
  </defs>
  <g filter="url(#plateShadow)">
    <path d="{plate}" fill="url(#plate)"/>
  </g>
  <path d="{plate}" fill="none" stroke="#0d2440" stroke-opacity="0.08" stroke-width="2"/>
  <g transform="translate({tx:.3f},{ty:.3f}) scale({scale:.6f})">{art}</g>
</svg>
''',
        encoding="utf-8",
    )
    print(f"wrote {OUT} (scale={scale:.4f} inset={PLATE_INSET:.0f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
