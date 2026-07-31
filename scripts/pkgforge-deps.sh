#!/bin/sh
# pkgforge-deps.sh — Install build dependencies inside Arch Linux container
set -eu

echo "[pkgforge] Updating Arch Linux..."
pacman -Syu --noconfirm

echo "[pkgforge] Installing system build dependencies..."
pacman -S --noconfirm zstd desktop-file-utils

echo "[pkgforge] Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv --version

echo "[pkgforge] Installing Python 3.11 via uv..."
uv python install 3.11

echo "[pkgforge] Installing project Python dependencies..."
uv sync

echo "[pkgforge] Debloating for smaller AppImage..."
get-debloated-pkgs --add-common --prefer-nano

echo "[pkgforge] Dependencies ready."
