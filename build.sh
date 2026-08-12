#!/bin/bash
# TenKeysTyping を .app バンドルとしてビルドする。
#   ./build.sh                → リリースビルドして TenKeysTyping.app を作る
#   ./build.sh --run          → ビルド後に起動する
#   ./build.sh --install      → /Applications へインストールする
#   ./build.sh --out <dir>    → 指定ディレクトリへ配置する
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TenKeysTyping"
BUNDLE="$APP_NAME.app"
CONFIG=release
DEST=""
RUN=false

while [ $# -gt 0 ]; do
  case "$1" in
    --run) RUN=true ;;
    --install) DEST="/Applications" ;;
    --out) shift; DEST="${1:?--out にはディレクトリを指定してください}" ;;
    *) echo "不明なオプション: $1" >&2; exit 1 ;;
  esac
  shift
done

# アイコンが未生成なら作る（source.svg を変えたときは make-icon.sh を直接実行する）
if [ ! -f Resources/AppIcon.icns ]; then
  ./Resources/icon/make-icon.sh
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUNDLE/Contents/Resources/AppIcon.icns"

# 署名なしだと Gatekeeper に止められることがあるので ad-hoc 署名しておく
codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "==> $BUNDLE を作成しました"

TARGET="$BUNDLE"
if [ -n "$DEST" ]; then
  mkdir -p "$DEST"
  rm -rf "${DEST%/}/$BUNDLE"
  cp -R "$BUNDLE" "${DEST%/}/"
  TARGET="${DEST%/}/$BUNDLE"
  # Finder / Dock のアイコンキャッシュを更新させる
  touch "$TARGET"
  echo "==> $TARGET へ配置しました"
fi

if [ "$RUN" = true ]; then
  open "$TARGET"
fi
