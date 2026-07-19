#!/bin/bash
# 署名なし IPA を作る。AltStore / SideStore がインストール時に再署名するため、
# ここでは証明書もプロビジョニングプロファイルも不要。
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="StaJun"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/$SCHEME.xcarchive"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild archive \
  -project "$SCHEME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS=""

# .app を Payload/ に入れて zip したものが IPA
APP="$ARCHIVE/Products/Applications/$SCHEME.app"
[ -d "$APP" ] || { echo "エラー: $APP が見つかりません" >&2; exit 1; }

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry "$SCHEME.ipa" Payload)
rm -rf "$BUILD_DIR/Payload"

echo "できました: $BUILD_DIR/$SCHEME.ipa ($(du -h "$BUILD_DIR/$SCHEME.ipa" | cut -f1))"
