#!/usr/bin/env bash
set -e

# 📍 Detecta el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 🐳 Nombre de la imagen (puedes cambiarlo)
IMAGE_NAME="gcc-esp32-toolchain-build"

# 🔨 Construye la imagen usando Podman
podman build -t "$IMAGE_NAME" "$SCRIPT_DIR"

