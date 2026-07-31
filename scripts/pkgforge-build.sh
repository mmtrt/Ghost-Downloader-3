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
# 2. Run quick-sharun directly on the binary
#    This auto-creates AppDir/usr/bin/ and traces system libraries
# ------------------------------------------------------------------
echo "[pkgforge] Running quick-sharun on binary..."
quick-sharun "$BINARY"

# ------------------------------------------------------------------
# 3. Copy remaining Nuitka dist files into AppDir
# ------------------------------------------------------------------
echo "[pkgforge] Copying Nuitka dist files into AppDir..."
for item in "$NUITKA_DIST"/*; do
    [ "$(basename "$item")" = "Ghost-Downloader-3.bin" ] && continue
    cp -a "$item" "AppDir/usr/bin/"
done

# ------------------------------------------------------------------
# 4. Add AppImage metadata (desktop file MUST be at AppDir root)
# ------------------------------------------------------------------
mkdir -p "AppDir/usr/share/applications" "AppDir/usr/share/icons/hicolor/256x256/apps"

cp "app/assets/logo.png" "AppDir/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"

# Create the .desktop file DIRECTLY at AppDir root (required by appimagetool)
cat > "AppDir/$APP_NAME.desktop" <<EOF
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

# Also copy into FHS location for inside-AppImage compliance
cp "AppDir/$APP_NAME.desktop" "AppDir/usr/share/applications/$APP_NAME.desktop"

# Icon links
ln -sf "usr/share/icons/hicolor/256x256/apps/$APP_NAME.png" "AppDir/$APP_NAME.png"
ln -sf "usr/share/icons/hicolor/256x256/apps/$APP_NAME.png" "AppDir/.DirIcon"

# AppRun symlink
ln -sf "usr/bin/Ghost-Downloader-3.bin" "AppDir/AppRun"

# Verify exactly one .desktop file exists at top level
DESKTOP_COUNT=$(find AppDir -maxdepth 1 -name "*.desktop" | wc -l)
if [ "$DESKTOP_COUNT" -ne 1 ]; then
    echo "[pkgforge] ERROR: Expected exactly 1 .desktop file at AppDir root, found $DESKTOP_COUNT"
    find AppDir -maxdepth 1 -name "*.desktop"
    exit 1
fi

echo "[pkgforge] AppDir contents:"
ls -la AppDir/

# ------------------------------------------------------------------
# 5. Create anylinux AppImage
# ------------------------------------------------------------------
echo "[pkgforge] Creating anylinux AppImage..."
quick-sharun --make-appimage

# ------------------------------------------------------------------
# 6. Rename outputs
# ------------------------------------------------------------------
mkdir -p dist
for f in ./*.AppImage ./*.AppImage.zsync; do
    [ -e "$f" ] || continue
    case "$f" in
        *.zsync)
            mv "$f" "dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage.zsync"
            echo "[pkgforge] Zsync: dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage.zsync"
            ;;
        *)
            mv "$f" "dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage"
            echo "[pkgforge] AppImage: dist/Ghost-Downloader-v${VERSION}-Linux-${ARCH}.AppImage"
            ;;
    esac
done

echo "[pkgforge] Done."
