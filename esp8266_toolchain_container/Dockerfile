FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV IDF_PATH=/sdk/ESP8266_RTOS_SDK

# Argumento para el directorio de paquetes .deb
ARG DEB_DIR=debs

# Directorio de trabajo para tus proyectos
WORKDIR /workspace

# Copia los paquetes .deb al contenedor
COPY ${DEB_DIR}/ /tmp/debs/

# Instala CMake, libusb y Python para flasheo
RUN apt-get update && \
    apt-get install -y \
        cmake \
        libusb-1.0-0-dev \
	git \
	wget \
	make \
	libncurses-dev \
	flex \ 
	bison \
	gperf \
        ninja-build \
        python3 \
        python3-pip \
        python3-serial && \
    dpkg -i /tmp/debs/*.deb || apt-get -f install -y && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    rm -rf /var/lib/apt/lists/* /tmp/debs

RUN mkdir /sdk
WORKDIR /sdk
#RUN git clone --recursive https://github.com/espressif/ESP8266_RTOS_SDK.git && cd ESP8266_RTOS_SDK && pip3 install -r requirements.txt esptool --break-system-packages
RUN pip3 install esptool --break-system-packages

RUN wget -O cmake-4.2.1-linux-x86_64.sh https://github.com/Kitware/CMake/releases/download/v4.2.1/cmake-4.2.1-linux-x86_64.sh 

RUN chmod a+x cmake-4.2.1-linux-x86_64.sh 
RUN ./cmake-4.2.1-linux-x86_64.sh --prefix=/opt --include-subdir --skip-license
ENV PATH="/opt/cmake-4.2.1-linux-x86_64/bin:${PATH}"
# Entrar al contenedor con shell por defecto
CMD ["/bin/bash"]

