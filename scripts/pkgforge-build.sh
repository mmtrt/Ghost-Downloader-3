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
export ICON=app/assets/logo.png
export DESKTOP=app/assets/ghost-downloader.desktop
export DEPLOY_QT=1

APP_NAME="ghost-downloader"
NUITKA_DIST="dist/Ghost-Downloader-3.dist"
BINARY="$NUITKA_DIST/Ghost-Downloader-3.bin"
APPDIR="AppDir"

echo "[pkgforge] Building Ghost Downloader v$VERSION for $ARCH..."

# ------------------------------------------------------------------
# 1. Build with Nuitka (same command as your Ubuntu job)
# ------------------------------------------------------------------
uv run scripts/deploy.py

if [ ! -f "$BINARY" ]; then
    echo "[pkgforge] ERROR: Nuitka binary not found at $BINARY"
    exit 1
fi
chmod +x "$BINARY"

# ------------------------------------------------------------------
# 2. Prepare AppDir (FHS layout inside AppDir/)
# ------------------------------------------------------------------
echo "[pkgforge] Preparing AppDir..."
rm -rf "$APPDIR"
mkdir -p     "$APPDIR/usr/bin"     "$APPDIR/usr/lib/$APP_NAME"     "$APPDIR/usr/share/applications"     "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy the entire Nuitka dist folder (contains stdlib, Qt plugins, etc.)
cp -a "$NUITKA_DIST"/. "$APPDIR/usr/lib/$APP_NAME/"

# Symlink main binary into PATH
ln -s "/usr/lib/$APP_NAME/Ghost-Downloader-3.bin" "$APPDIR/usr/bin/$APP_NAME"

# AppRun entry point
ln -s "usr/bin/$APP_NAME" "$APPDIR/AppRun"

# Desktop file
cat > "$APPDIR/usr/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ghost Downloader
Comment=A multi-threading downloader based on PySide6
Exec=$APP_NAME
Icon=$APP_NAME
Terminal=false
Categories=Network;Utility;
StartupNotify=false
EOF
ln -s "usr/share/applications/$APP_NAME.desktop" "$APPDIR/$APP_NAME.desktop"

# Icon
cp "app/assets/logo.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
ln -s "usr/share/icons/hicolor/256x256/apps/$APP_NAME.png" "$APPDIR/$APP_NAME.png"
ln -s "usr/share/icons/hicolor/256x256/apps/$APP_NAME.png" "$APPDIR/.DirIcon"

# ------------------------------------------------------------------
# 3. Trace & bundle any remaining system libraries with quick-sharun
# ------------------------------------------------------------------
echo "[pkgforge] Running quick-sharun to bundle system libraries..."
quick-sharun "$APPDIR/usr/bin/$APP_NAME"

# ------------------------------------------------------------------
# 4. Create anylinux AppImage
# ------------------------------------------------------------------
echo "[pkgforge] Creating anylinux AppImage..."
quick-sharun --make-appimage

# ------------------------------------------------------------------
# 5. Rename outputs to match your release convention
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
