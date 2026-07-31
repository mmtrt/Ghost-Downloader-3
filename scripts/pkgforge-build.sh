#!/bin/sh
# pkgforge-build.sh — Build Nuitka app and package as anylinux AppImage
set -eu

ARCH=$(uname -m)
VERSION="${VERSION:-$(python3 -c "exec(open('app/config/constants.py').read()); print(VERSION)")}"
REPO="${GH_REPO:-${GITHUB_REPOSITORY:-user/repo}}"

export ARCH
export VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${REPO%/*}|${REPO#*/}|latest|*$ARCH.AppImage.zsync"
export DEPLOY_QT=1

APP_NAME="ghost-downloader"
NUITKA_DIST="dist/Ghost-Downloader-3.dist"
BINARY="$NUITKA_DIST/Ghost-Downloader-3.bin"

echo "[pkgforge] Building Ghost Downloader v$VERSION for $ARCH..."

# ------------------------------------------------------------------
# 1. Build with Nuitka
# ------------------------------------------------------------------
uv run scripts/deploy.py

if [ ! -f "$BINARY" ]; then
    echo "[pkgforge] ERROR: Nuitka binary not found at $BINARY"
    exit 1
fi
chmod +x "$BINARY"

# ------------------------------------------------------------------
# 2. Create .desktop and icon files BEFORE quick-sharun runs.
# ------------------------------------------------------------------
cat > "$NUITKA_DIST/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ghost Downloader
Comment=A multi-threading downloader based on PySide6
Exec=Ghost-Downloader-3.bin
Icon=$APP_NAME
Terminal=false
Categories=Network;Utility;
StartupNotify=false
EOF

cp "app/assets/logo.png" "$NUITKA_DIST/$APP_NAME.png"

export DESKTOP="$NUITKA_DIST/$APP_NAME.desktop"
export ICON="$NUITKA_DIST/$APP_NAME.png"

echo "[pkgforge] DESKTOP=$DESKTOP  (exists=$(test -f "$DESKTOP" && echo yes || echo no))"
echo "[pkgforge] ICON=$ICON  (exists=$(test -f "$ICON" && echo yes || echo no))"

# ------------------------------------------------------------------
# 3. quick-sharun creates AppDir/ and traces system libraries.
# ------------------------------------------------------------------
echo "[pkgforge] Running quick-sharun on binary..."
quick-sharun "$BINARY"

# ------------------------------------------------------------------
# 4. Find where quick-sharun placed the binary and copy remaining files
# ------------------------------------------------------------------
BUNDLED_BINARY=$(find AppDir -name "Ghost-Downloader-3.bin" -type f | head -1)
if [ -z "$BUNDLED_BINARY" ]; then
    echo "[pkgforge] ERROR: Could not find bundled binary in AppDir"
    exit 1
fi

BINDIR=$(dirname "$BUNDLED_BINARY")
echo "[pkgforge] Binary located at: $BUNDLED_BINARY"
echo "[pkgforge] Copying remaining Nuitka dist files to: $BINDIR"

for item in "$NUITKA_DIST"/*; do
    basename_item=$(basename "$item")
    [ "$basename_item" = "Ghost-Downloader-3.bin" ] && continue
    [ "$basename_item" = "$APP_NAME.desktop" ] && continue
    [ "$basename_item" = "$APP_NAME.png" ] && continue
    cp -a "$item" "$BINDIR/"
done

# ------------------------------------------------------------------
# 5. Verify .desktop at AppDir root
# ------------------------------------------------------------------
echo "[pkgforge] AppDir top-level files:"
ls -la AppDir/

desktop_count=$(find AppDir -maxdepth 1 -name "*.desktop" | wc -l)
if [ "$desktop_count" -ne 1 ]; then
    echo "[pkgforge] ERROR: Expected 1 .desktop at AppDir root, found $desktop_count"
    exit 1
fi

# ------------------------------------------------------------------
# 6. Create anylinux AppImage
# ------------------------------------------------------------------
echo "[pkgforge] Creating anylinux AppImage..."
quick-sharun --make-appimage

# ------------------------------------------------------------------
# 7. Rename outputs to match release convention
#    quick-sharun produces: Ghost_Downloader-4.2.2-anylinux-x86_64.AppImage
#    We need:               Ghost-Downloader-v4.2.2-Linux-x86_64.AppImage
# ------------------------------------------------------------------
mkdir -p dist

# Find the generated AppImage (should be in cwd, name derived from .desktop Name= field)
SRC_APPIMAGE=$(find . ./dist -maxdepth 1 -name "*.AppImage" -type f 2>/dev/null | head -1)
SRC_ZSYNC=$(find . ./dist -maxdepth 1 -name "*.AppImage.zsync" -type f 2>/dev/null | head -1)

if [ -z "$SRC_APPIMAGE" ]; then
    echo "[pkgforge] ERROR: No .AppImage file found in cwd after build"
    ls -la
    exit 1
fi

DST_APPIMAGE="dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage"
DST_ZSYNC="dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage.zsync"

echo "[pkgforge] Renaming: $SRC_APPIMAGE -> $DST_APPIMAGE"
mv "$SRC_APPIMAGE" "$DST_APPIMAGE"

if [ -n "$SRC_ZSYNC" ] && [ -f "$SRC_ZSYNC" ]; then
    echo "[pkgforge] Renaming: $SRC_ZSYNC -> $DST_ZSYNC"
    mv "$SRC_ZSYNC" "$DST_ZSYNC"
else
    echo "[pkgforge] No .zsync file found (this is OK if zsync is disabled)"
fi

echo "[pkgforge] Final dist/ contents:"
ls -la dist/

echo "[pkgforge] Done."
