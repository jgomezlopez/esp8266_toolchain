#!/bin/bash
set -e

IMAGE_NAME=esp8266-toolchain-cmake:latest
PROJECT_DIR="$(pwd)"
TTY_FLAG=""

# 🧠 Parseo de argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      shift
      PROJECT_DIR="$1"
      ;;
    --device)
      shift
      TTY_DEVICE="$1"
      ;;
    *)
      echo "❌ Argumento desconocido: $1"
      echo "Uso: $0 [--path <directorio>] [--device <dispositivo>]"
      exit 1
      ;;
  esac
  shift
done

# Verifica que el directorio exista
if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ El directorio '$PROJECT_DIR' no existe."
  exit 1
fi

# Si se especificó un dispositivo, construye el flag
if [ -n "$TTY_DEVICE" ]; then
  if [ ! -e "$TTY_DEVICE" ]; then
    echo "⚠️  El dispositivo '$TTY_DEVICE' no existe. Continuando sin montarlo."
  else
    TTY_FLAG="--device=$TTY_DEVICE --group-add dialout"
  fi
fi

echo "🚀 Lanzando contenedor..."
echo "📂 Proyecto: $PROJECT_DIR"
[[ -n "$TTY_FLAG" ]] && echo "🔌 Dispositivo: $TTY_DEVICE"

 #
sudo podman run --rm -it \
  --privileged \
  $TTY_FLAG \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -v "$PROJECT_DIR":/workspace \
  -w /workspace \
  $IMAGE_NAME 

