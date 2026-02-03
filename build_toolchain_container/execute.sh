#!/usr/bin/env bash
set -e

# 📍 Usa el primer argumento como directorio de trabajo, o el actual si no se pasa nada
WORKDIR="${1:-$(pwd)}"

# 🐳 Nombre de la imagen (ajústalo si usaste otro)
IMAGE_NAME="gcc-esp32-toolchain-build"

#--userns=keep-id \
# 🔁 Ejecuta el contenedor con el volumen montado
podman run -it --rm \
  --network host \
  -v "$WORKDIR:/workspace" \
  -w /workspace \
  "$IMAGE_NAME" \
  bash

