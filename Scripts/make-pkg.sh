#!/bin/bash
# build/QuitAll.app → build/QuitAll-<versión>.pkg (instala en /Applications y abre la configuración inicial)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-1.0.0}"
[[ -d build/QuitAll.app ]] || Scripts/build-app.sh
W="$(mktemp -d)"
mkdir -p "$W/root" "$W/scripts"
cp -R build/QuitAll.app "$W/root/"
cat > "$W/scripts/postinstall" <<'SH'
#!/bin/bash
# Abre la app como el usuario con la sesión iniciada (el instalador corre como root). --no-run: abrirla así no cierra nada.
U="$(stat -f%Su /dev/console)"
[ -n "$U" ] && [ "$U" != "root" ] && sudo -u "$U" open -a /Applications/QuitAll.app --args --no-run || true
exit 0
SH
chmod +x "$W/scripts/postinstall"
# Sin esto, Installer «reubica» la app si encuentra otra copia con el mismo bundle ID (p. ej. build/QuitAll.app).
pkgbuild --analyze --root "$W/root" "$W/component.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$W/component.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$W/component.plist"
pkgbuild --root "$W/root" --component-plist "$W/component.plist" --scripts "$W/scripts" --identifier com.jdevesablanco.quitall.pkg \
  --version "$VERSION" --install-location /Applications "$W/QuitAll-component.pkg" >/dev/null
cat > "$W/dist.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
  <title>QuitAll</title>
  <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <choices-outline><line choice="default"><line choice="app"/></line></choices-outline>
  <choice id="default"/>
  <choice id="app" visible="false"><pkg-ref id="com.jdevesablanco.quitall.pkg"/></choice>
  <pkg-ref id="com.jdevesablanco.quitall.pkg" version="$VERSION" onConclusion="none">QuitAll-component.pkg</pkg-ref>
</installer-gui-script>
XML
rm -f "build/QuitAll-$VERSION.pkg"
productbuild --distribution "$W/dist.xml" --package-path "$W" "build/QuitAll-$VERSION.pkg" >/dev/null
rm -rf "$W"
echo "✓ build/QuitAll-$VERSION.pkg"
