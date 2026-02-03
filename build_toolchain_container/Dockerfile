FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 🔧 Instala solo los paquetes necesarios para compilar
RUN apt-get update && apt-get install -y \
    build-essential \
    bison \
    flex \
    libgmp3-dev \
    libmpc-dev \
    libmpfr-dev \
    libisl-dev \
    texinfo \
    wget \
    cmake \
    git \
    python3 \
    meson \
    ninja-build \
    python3-pip \
    ca-certificates \
    gperf \
    texinfo \
    libtool \
    libtool-bin \
    libncurses5-dev \
    gawk \
    help2man \
    libexpat-dev \
    autoconf \
    automake \
    python3-serial \
    && rm -rf /var/lib/apt/lists/*

# 📁 Punto de entrada: usar volumen externo
WORKDIR /toolchain

# 🏁 Comando por defecto (puedes sobreescribirlo al ejecutar)
CMD ["/bin/bash"]

