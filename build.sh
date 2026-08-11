#!/bin/bash
# TenKeysTyping を .app バンドルとしてビルドする。
#   ./build.sh          → リリースビルドして TenKeysTyping.app を作る
#   ./build.sh --run    → ビルド後に起動する
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="TenKeysTyping"
BUNDLE="$APP_NAME.app"
CONFIG=release

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$BUNDLE/Contents/Info.plist"

# 署名なしだと Gatekeeper に止められることがあるので ad-hoc 署名しておく
codesign --force --sign - "$BUNDLE" >/dev/null 2>&1 || true

echo "==> $BUNDLE を作成しました"

if [ "${1:-}" = "--run" ]; then
  open "$BUNDLE"
fi
