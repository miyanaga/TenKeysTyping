#!/bin/bash
# source.svg から Resources/AppIcon.icns を生成する。
#   compose.py で 1024x1024 の AppIcon.svg を組み立て
#   → qlmanage(WebKit) で PNG にラスタライズ
#   → sips で各サイズを作り iconutil で .icns にまとめる
# ImageMagick の内蔵 SVG レンダラは品質が安定しないので使わない。
set -euo pipefail

cd "$(dirname "$0")"

python3 compose.py

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

qlmanage -t -s 1024 -o "$WORK" AppIcon.svg >/dev/null 2>&1
MASTER="$WORK/AppIcon.svg.png"
[ -f "$MASTER" ] || { echo "SVG のラスタライズに失敗しました" >&2; exit 1; }

SET="$WORK/AppIcon.iconset"
mkdir -p "$SET"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
            "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
            "512 512x512" "1024 512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" "$MASTER" --out "$SET/icon_$2.png" >/dev/null
done

iconutil -c icns "$SET" -o ../AppIcon.icns
echo "==> Resources/AppIcon.icns を生成しました"
