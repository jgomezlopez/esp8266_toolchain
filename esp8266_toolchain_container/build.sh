#!/bin/bash
set -e

IMAGE_NAME=esp8266-toolchain-cmake

# 🧠 Usa primer argumento como DEB_DIR, o 'debs' si no existe
INPUT_DEB_DIR="${1:-debs}"
if [ ! -d "$INPUT_DEB_DIR" ]; then
  echo "❌ El directorio '$INPUT_DEB_DIR' no existe."
  exit 1
fi

# 🧪 Crea copia local dentro del contexto de build
TEMP_DEB_DIR="./debs-temp"
rm -rf "$TEMP_DEB_DIR"
mkdir -p "$TEMP_DEB_DIR"
cp "$INPUT_DEB_DIR"/*.deb "$TEMP_DEB_DIR"

echo "🔧 Construyendo imagen Podman '$IMAGE_NAME' usando paquetes de '$INPUT_DEB_DIR'..."

podman build -t $IMAGE_NAME -f Dockerfile \
  --build-arg DEB_DIR=debs-temp

# Limpieza quirúrgica
rm -rf "$TEMP_DEB_DIR"

echo "✅ Imagen '$IMAGE_NAME' construida correctamente."

