#!/bin/bash
# Compila QuitAll y monta build/QuitAll.app (con la CLI dentro).
#   Scripts/build-app.sh                 → firma ad-hoc (gratis, funciona en tu Mac)
#   SIGN_ID="Developer ID Application: …" Scripts/build-app.sh   → firma con tu certificado (para notarizar)
#   UNIVERSAL=1 Scripts/build-app.sh     → binario arm64 + x86_64 (necesita Xcode)
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "${QUITALL_NO_SANDBOX:-0}" == "1" ]] && SWIFTPM_FLAGS="--disable-sandbox" || true

BUNDLE_ID="${BUNDLE_ID:-com.jdevesablanco.quitall}"
VERSION="${VERSION:-1.0.0}"
SIGN_ID="${SIGN_ID:--}"
OUT="${OUT:-build}"
APP="$OUT/QuitAll.app"

ARCHS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then ARCHS=(--arch arm64 --arch x86_64); fi
swift build -c release ${SWIFTPM_FLAGS:-} ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${SWIFTPM_FLAGS:-} ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/QuitAllApp" "$APP/Contents/MacOS/QuitAll"
cp "$BIN/quitall" "$APP/Contents/Resources/quitall"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/@BUNDLE_ID@/$BUNDLE_ID/g" -e "s/@VERSION@/$VERSION/g" Resources/Info.plist.template > "$APP/Contents/Info.plist"

OPTS=()
if [[ "$SIGN_ID" != "-" ]]; then OPTS=(--options runtime --timestamp); fi
codesign --force --sign "$SIGN_ID" ${OPTS[@]+"${OPTS[@]}"} "$APP/Contents/Resources/quitall"
codesign --force --sign "$SIGN_ID" ${OPTS[@]+"${OPTS[@]}"} "$APP"
codesign --verify --deep --strict "$APP" && echo "✓ firma verificada ($([[ "$SIGN_ID" == "-" ]] && echo ad-hoc || echo "$SIGN_ID"))"
echo "✓ $APP"
