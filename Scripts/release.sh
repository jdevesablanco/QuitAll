#!/bin/bash
# Uso: Scripts/release.sh 1.0.1
# 1) sube la versión en app, CLI, fórmula y cask  2) crea el tag y lo empuja (la CI publica DMG + PKG en el Release)
# 3) cuando el Release existe, rellena los sha256 de la fórmula y del cask para el tap jdevesablanco/homebrew-tap.
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:?uso: Scripts/release.sh X.Y.Z}"
sed -i '' "s|archive/refs/tags/v[0-9.]*\.tar\.gz|archive/refs/tags/v$V.tar.gz|" homebrew/Formula/quitall.rb
sed -i '' "s|version \"[0-9.]*\"|version \"$V\"|" homebrew/Casks/quitall.rb
sed -i '' "s|^let version = \"[0-9.]*\"|let version = \"$V\"|" Sources/QuitAllCLI/main.swift
sed -i '' "s|static let version = \"[0-9.]*\"|static let version = \"$V\"|" Sources/QuitAllApp/Support.swift
git add -A && git commit -m "Release v$V" && git tag "v$V" && git push origin main "v$V"

echo "Esperando a que la CI publique el DMG…"
DMG="https://github.com/jdevesablanco/QuitAll/releases/download/v$V/QuitAll-$V.dmg"
until curl -sfIL "$DMG" >/dev/null; do sleep 20; done
SRC_SHA="$(curl -sL "https://github.com/jdevesablanco/QuitAll/archive/refs/tags/v$V.tar.gz" | shasum -a 256 | cut -d' ' -f1)"
DMG_SHA="$(curl -sL "$DMG" | shasum -a 256 | cut -d' ' -f1)"
sed -i '' "s|sha256 \"[0-9a-zA-Z_]*\"|sha256 \"$SRC_SHA\"|" homebrew/Formula/quitall.rb
sed -i '' "s|sha256 \"[0-9a-zA-Z_]*\"|sha256 \"$DMG_SHA\"|" homebrew/Casks/quitall.rb
echo "Fórmula sha256 = $SRC_SHA · Cask sha256 = $DMG_SHA"
echo "Copia homebrew/Formula/quitall.rb y homebrew/Casks/quitall.rb a jdevesablanco/homebrew-tap y haz push."
