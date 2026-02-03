# Modern C++ toolchain for ESP-8266 (xtensa-lx106)

With the content of this repo you are able to build a toolchain for xtensa-lx106 (tested on ESP-8266 boards). The script has been tested to build a toolchain with the following features:
- binutils 2.45
- GCC 15.2 with C and C++ support
- newlib 4.5.0-2024016
- Expressif SDKs are not supported
- It has been tested with examples in repo [C++ examples for baremetal ESP-8266](https://github.com/jgomezlopez/esp8266_no_sdk_baremetal_cpp)
- Concepts, deduced this and modules were tested with this toolchain

It can be customized by suplying the versions of the enumerated tools.

## Script build-toolchain.sh

This script perform the following tasks:

1. Download binutils, gcc, newlib, xtensa ovelays and Expressif NONOS SDK packages
2. Uncompress them and apply overlays patch to binutils and gcc
3. Bootstrap stage
    1. Build binutils for xtensa-lx106
    2. Build gcc with only C support for xtensa-lx106 and not using host libc
    3. Build newlib with just built C compiler
4. Final stage
    1. Build binutils with just built C compiler
    2. Build gcc with C and C++ support and linked to newlib
    3. Build newlib with the latest C compiler.
5. Toolchain verification by compiling a minimal example and linking to Expressif NONOS SDK.
6. Create Debian packages of the toolchain.
    - binutils
    - gcc
    - g++
    - newlib
 
This process is based on Slackware building C toolchain for xtensa-lx106 provided by Michel Stam.

## Toolchain builder container

This podman container installs all the packages are needed to download source packages, build the toolchain and build the Debian packages.

The build-toolchain.sh should be executed in this conatiner.

##  Toolchain container

This container installs the toolchain Debian packages, cmake 4.2.1 and esptool to upload binaries to the ESP-8266 board.

## Steps using podman containers

The preferred way of building the toolchain is using the Podman container which you can build using the scripts and definitions from ```build_toolchain_container``` directory and for building ESP-8266 binaries it is highly recommended to use the scripts and definition located in ```esp8266_toolchain_container``` directory.

1. Build toolchain builder container.
    Run the building script in the build_toochain_container directory
    ``` bash
    $ build_toolchain_container/build.sh
    ```

2. Execute the container from the script directory.
    ``` bash
    $ cd scripts
    $ ../build_toolchain_container/execute.sh
    ```

3. Execute the building script inside the container.
    ``` bash
    ./build-toolchain.sh --gcc 15.2.0 --binutils 2.45 --newlib 4.5.0.20241231 --overlays 2022r1 
    ```
    - gcc version: 15.2.0
    - binutils version: 2.45
    - newlib version: 4.5.0.20241231
    - ovelays version: 2022r1

    If you want to use different vesions, just specify the desired version for each component.
    If the process has been properly execute a directory debs has been created with the Debian packages.
    ``` bash
    exit
    ```

4. Build the toolchain container.
    Run the building script in the esp8266_toolchain_container directory
    ``` bash
    $ esp8266_toolchain_container/build.sh scripts/debs
    ```
    scripts/debs is the directory where the Debian packages have been placed

5. Execute the toolchain container.
    Move to the folder where you have the project you want to build, connect your ESP-8266 board to an USB port and execute the podman container.
    ``` bash
    $ cd <my_project_dir>
    $ /xxxx/esp8266_toolchain_container/execute.sh --device /dev/ttyUSB0
    ```
6. Execute your building process and upload the generated image to the board. [See C++ examples for baremetal ESP-8266](https://github.com/jgomezlopez/esp8266_no_sdk_baremetal_cpp)
    
