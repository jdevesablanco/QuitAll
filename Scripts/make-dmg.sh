#!/bin/bash
# build/QuitAll.app → build/QuitAll-<versión>.dmg (con acceso directo a Aplicaciones)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
[[ -d build/QuitAll.app ]] || Scripts/build-app.sh
STAGE="$(mktemp -d)"
cp -R build/QuitAll.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/LEEME - README.txt" <<'TXT'
QuitAll — arrastra QuitAll.app a Aplicaciones y ábrela con clic derecho → Abrir (solo la primera vez).
Si macOS dice que no puede verificar la app: Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente».
(La app no está notarizada por Apple; es software libre y el código está en GitHub.)

QuitAll — drag QuitAll.app to Applications and open it with right-click → Open (first time only).
If macOS says it can't verify the app: System Settings → Privacy & Security → "Open Anyway".
(The app isn't notarized by Apple; it's free software and the code is on GitHub.)
TXT
rm -f "build/QuitAll-$VERSION.dmg"
hdiutil create -volname "QuitAll" -srcfolder "$STAGE" -ov -format UDZO "build/QuitAll-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"
echo "✓ build/QuitAll-$VERSION.dmg"
