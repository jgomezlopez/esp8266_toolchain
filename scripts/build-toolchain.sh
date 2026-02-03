#!/bin/bash
#
# This shell script makes packages from the binutils, gcc and newlib sources.
# Author:       Michel Stam, <michel@reverze.net>
# Adapted by:   Jose Gomez-Lopez, <jose.gomez.lopez@gmail.com>
#
ARCH=`/bin/arch`
CURRENTDIR=`pwd`
if [ "$ARCH" == "x86_64" ]; then
	PLATFORM=x86_64
	LIBDIR=lib64
	CFLAGS="-O2 -fPIC -march=x86-64 -mtune=k8"
else
	PLATFORM=i486
	LIBDIR=lib
	CFLAGS="-O2 -march=i486 -mtune=i686"
fi

pythonver() {
	ver=`python --version 2>&1 | tr . ' '`
	set -- $ver
	echo $2.$3
}

parse_args() {
    # Valores por defecto
    OVERLAYS_VERSION=2022r1
    BINUTILS_VERSION=2.45
    GCC_VERSION=15.2.0
    ESP_SDK_VERSION=3.0.6
    NEWLIB_VERSION=4.5.0.20241231

    # Bucle de análisis
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --overlays)
                OVERLAYS_VERSION="$2"
                shift 2
                ;;
            --binutils)
                BINUTILS_VERSION="$2"
                shift 2
                ;;
            --gcc)
                GCC_VERSION="$2"
                shift 2
                ;;
            --sdk-nonos)
                ESP_SDK_VERSION="$2"
                shift 2
                ;;
            --newlib)
                NEWLIB_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                echo "Available options:"
                echo "  --overlays <string>     (default 2022r1)"
                echo "  --binutils <string>     (default 2.45)"
                echo "  --gcc <string>          (default 15.2.0)"
                echo "  --sdk-nonos <string>    (default 3.0.6)"
                echo "  --newlib <string>       (default 4.5.0.20241231)"
                exit 0
                ;;
            *)
                echo "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done
}

parse_args "$@"

LIBC_LIBRARY="newlib"

RELEASE=3
MAKEOPT="make -j $(( `grep -c processor /proc/cpuinfo` + 1 ))"
PYTHONDIR=${LIBDIR}/python$(pythonver)/site-packages
SOURCEDIR=/tmp/toolchain
STAGEDIR=/tmp/toolchain/staging
CROSS="xtensa-lx106-elf"

OVERLAYS_ORIG_PKG=esp-${OVERLAYS_VERSION}
OVERLAYS_PKG=xtensa-overlays-${OVERLAYS_ORIG_PKG}
OVERLAYS_PKGFILE=${OVERLAYS_PKG}.tar.gz
OVERLAYS_BOARD="xtensa_esp8266"
if [ ! -f "${OVERLAYS_PKGFILE}" ]; then
      if ! wget -O ${OVERLAYS_PKGFILE} https://github.com/espressif/xtensa-overlays/archive/refs/tags/${OVERLAYS_ORIG_PKG}.tar.gz; then
	      echo "❌ Failed to download overlays"; exit 1; 
      fi
fi

BINUTILS_PKG=binutils-${BINUTILS_VERSION}
BINUTILS_PKGFILE=${BINUTILS_PKG}.tar.xz
BINUTILS_BUILD="--disable-nls --enable-multilib --disable-werror --disable-linker-plugin"
BINUTILS_PKGDIR=/tmp/toolchain/binutils
if [ ! -f "${BINUTILS_PKGFILE}" ]; then
      if ! wget -O ${BINUTILS_PKGFILE} https://ftp.gnu.org/gnu/binutils/${BINUTILS_PKGFILE}; then
	      echo "❌ Failed to download binutils"; exit 1; 
      fi
fi

GCC_PKG=gcc-${GCC_VERSION}
GCC_PKGFILE=${GCC_PKG}.tar.xz
GCC_BUILD="--enable-host-shared --disable-shared --disable-threads --with-newlib -with-gnu-ld --with-gnu-as --enable-target-optspace --disable-libgomp --disable-libmudflap --disable-multilib --disable-nls --disable-libsanitizer --enable-poison-system-directories --disable-libssp --enable-__cxa_atexit --with-sysroot=/usr/${CROSS} --with-python-dir=${PYTHONDIR} --libdir=/usr/${LIBDIR}"
GCC_PKGDIR=/tmp/toolchain/gcc
if [ ! -f "${GCC_PKGFILE}" ]; then
      if ! wget -O ${GCC_PKGFILE} https://ftp.gnu.org/gnu/gcc/${GCC_PKG}/${GCC_PKGFILE}; then
	      echo "❌ Failed to download gcc"; exit 1; 
      fi
fi

GXX_VERSION=${GCC_VERSION}
GXX_PKG=${GCC_PKG/gcc/gcc-g++}
GXX_PKGDIR=/tmp/toolchain/gxx

NEWLIB_PKG=newlib-${NEWLIB_VERSION}
NEWLIB_PKGFILE=${NEWLIB_PKG}.tar.gz
NEWLIB_BUILD="--disable-multilib --disable-libgloss --enable-newlib-io-long-long --enable-newlib-io-c99-formats --enable-newlib-register-fini --with-sysroot=/tmp/toolchain/staging/usr"
NEWLIB_PKGDIR=/tmp/toolchain/newlib
if [ ! -f "${NEWLIB_PKGFILE}" ]; then
      if ! wget -O ${NEWLIB_PKGFILE} ftp://sourceware.org/pub/newlib/${NEWLIB_PKGFILE}; then
	      echo "❌ Failed to download newlib"; exit 1; 
      fi
fi

COMMON_BUILD="--prefix=/usr --mandir=/usr/man --datarootdir=/usr --with-gmp-lib=/usr/${LIBDIR} --with-gmp-include=/usr/include --with-mpfr-lib=/usr/${LIBDIR} --with-mpfr-include=/usr/include --with-mpc-lib=/usr/${LIBDIR} --with-mpc-include=/usr/include --with-isl-lib=/usr/${LIBDIR} --with-isl-include=/usr/include --host=${PLATFORM}-linux-gnu --build=${PLATFORM}-linux-gnu --target=${CROSS} --with-endian=little --with-isa=lx106"


ESP_SDK_VERSION=3.0.6
ESP_SDK_PKG=ESP8266_NONOS_SDK-$ESP_SDK_VERSION
ESP_SDK_PKGFILE=${ESP_SDK_PKG}.tar.gz
ESP_SDK_PKGDIR=/tmp/toolchain/esp-sdk
if [ ! -f "${ESP_SDK_PKGFILE}" ]; then
      if ! wget -O ${ESP_SDK_PKGFILE} https://github.com/espressif/ESP8266_NONOS_SDK/archive/refs/tags/v${ESP_SDK_VERSION}.tar.gz; then
	      echo "❌ Failed to download ESP NONOS SDK"; exit 1; 
      fi
fi

export PATH=$PATH:${STAGEDIR}/usr/bin

#####################################################
# Create build environment and package skeleton
#####################################################
mkdir -p ${SOURCEDIR} \
         ${STAGEDIR} \
         ${BINUTILS_PKGDIR} \
         ${SOURCEDIR}/${BINUTILS_PKG}/bootstrap \
         ${SOURCEDIR}/${BINUTILS_PKG}/final \
         ${GCC_PKGDIR} \
         ${GXX_PKGDIR} \
         ${SOURCEDIR}/${GCC_PKG}/bootstrap \
         ${SOURCEDIR}/${GCC_PKG}/final \
         ${ESP_SDK_PKGDIR}/opt \
	 ${NEWLIB_PKGDIR} \
         ${SOURCEDIR}/${NEWLIB_PKG}/bootstrap \
         ${SOURCEDIR}/${NEWLIB_PKG}/final

for TODO in ${BINUTILS_PKGFILE} ${GCC_PKGFILE} ${OVERLAYS_PKGFILE} ${NEWLIB_PKGFILE}; do
	tar -x -f ${TODO} -C ${SOURCEDIR}
done
tar -x -f ${ESP_SDK_PKGFILE} -C ${ESP_SDK_PKGDIR}/opt
cp gen_appbin.py ${ESP_SDK_PKGDIR}/opt/ESP8266_NONOS_SDK-${ESP_SDK_VERSION}/tools/

mkdir deb
DEBIAN_PKG_DIR="$(pwd)/deb"

# TODO: Verify if it is needed
#cp elf32xtensa.sh ${SOURCEDIR}/${BINUTILS_PKG}/ld/emulparams/elf32xtensa.sh

# Create installation folder structure
mkdir -p ${BINUTILS_PKGDIR}/usr/info/ \
	 ${BINUTILS_PKGDIR}/usr/man/man1/ \
	 ${BINUTILS_PKGDIR}/usr/bin/ \
	 ${BINUTILS_PKGDIR}/usr/doc/ \
	 ${BINUTILS_PKGDIR}/usr/xtensa-lx106-elf/bin/ \
	 ${BINUTILS_PKGDIR}/usr/xtensa-lx106-elf/lib/ \
	 ${BINUTILS_PKGDIR}/install/ \
	 ${BINUTILS_PKGDIR}/usr/${LIBDIR}/xtensa-lx106-elf/bfd-plugins/ \
	 ${GCC_PKGDIR}/usr/info/ \
	 ${GCC_PKGDIR}/usr/man/ \
	 ${GCC_PKGDIR}/usr/man/man1/ \
	 ${GCC_PKGDIR}/usr/bin/ \
	 ${GCC_PKGDIR}/usr/doc/ \
	 ${GCC_PKGDIR}/usr/libexec/ \
	 ${GCC_PKGDIR}/install/ \
	 ${GCC_PKGDIR}/usr/${LIBDIR}/ \
	 ${NEWLIB_PKGDIR}/usr/xtensa-lx106-elf/lib/ \
	 ${NEWLIB_PKGDIR}/usr/xtensa-lx106-elf/include/ \
	 ${NEWLIB_PKGDIR}/install/

#####################################################
# Build binutils from sources (bootstrap)
#####################################################

# Add overlays to binutils to support the right endian
cp ${SOURCEDIR}/${OVERLAYS_PKG}/${OVERLAYS_BOARD}/binutils/bfd/xtensa-modules.c ${SOURCEDIR}/${BINUTILS_PKG}/bfd/
cp ${SOURCEDIR}/${OVERLAYS_PKG}/${OVERLAYS_BOARD}/binutils/include/xtensa-config.h ${SOURCEDIR}/${BINUTILS_PKG}/include/
cd ${SOURCEDIR}/${BINUTILS_PKG}/bootstrap

CFLAGS="${CFLAGS}" ../configure ${BINUTILS_BUILD} ${COMMON_BUILD} --libdir=/usr/${LIBDIR}/${CROSS} || { echo "❌ Failed to configure binutils in bootstrap"; exit 1; }

make MAKE=${MAKEOPT} || { echo "❌ Failed to build binutils in bootstrap"; exit 1; }

#####################################################
# Copy binutils to staging (bootstrap)
#####################################################
make install DESTDIR=${STAGEDIR} || { echo "❌ Failed to install binutils in bootstrap"; exit 1; }

#####################################################
# Build gcc from sources (bootstrap)
#####################################################
cp ${SOURCEDIR}/${OVERLAYS_PKG}/${OVERLAYS_BOARD}/gcc/include/xtensa-config.h ${SOURCEDIR}/${GCC_PKG}/include/
cd ${SOURCEDIR}/${GCC_PKG}/bootstrap
CFLAGS="${CFLAGS}" CFLAGS_FOR_TARGET="-mlongcalls" CXXFLAGS_FOR_TARGET="-mlongcalls" ../configure ${GCC_BUILD} ${COMMON_BUILD} --without-headers --enable-languages=c --disable-fixincludes || { echo "❌ Failed to configure gcc in bootstrap"; exit 1; }

make MAKE=${MAKEOPT} all-gcc || { echo "❌ Failed to build gcc in bootstrap"; exit 1; }

#####################################################
# Copy gcc to staging (bootstrap)
#####################################################
make install-gcc DESTDIR=${STAGEDIR} || { echo "❌ Failed to install gcc in bootstrap"; exit 1; }

#####################################################
# Copy libgcc to staging (bootstrap)
#####################################################
make MAKE=${MAKEOPT} all-target-libgcc || { echo "❌ Failed to build libgcc in bootstrap"; exit 1; }
make install-target-libgcc DESTDIR=${STAGEDIR} || { echo "❌ Failed to install libgcc in bootstrap"; exit 1; }

#####################################################
# Build newlib from sources (bootstrap)
#####################################################
cd ${SOURCEDIR}/${NEWLIB_PKG}/bootstrap
../configure ${NEWLIB_BUILD} ${COMMON_BUILD} --libdir=/usr/${LIBDIR}/${CROSS} CFLAGS_FOR_TARGET="-D__DYNAMIC_REENT__ -DHAVE_INITFINI_ARRAY=1 -I$PWD/../newlib/libc/machine/xtensa/include" LDFLAGS_FOR_TARGET="-B${STAGEDIR}/usr/lib64/gcc/xtensa-lx106-elf/15.2.0/" || { echo "❌ Failed to configure newlib in bootstrap"; exit 1; }

make MAKE=${MAKEOPT} || { echo "❌ Failed to build newlib in bootstrap"; exit 1; }
make install DESTDIR=${STAGEDIR} || { echo "❌ Failed to install newlib in bootstrap"; exit 1; }

#####################################################
# Build binutils from sources (final)
#####################################################
cd ${SOURCEDIR}/${BINUTILS_PKG}/final

CFLAGS="${CFLAGS}" ../configure ${BINUTILS_BUILD} ${COMMON_BUILD} --libdir=/usr/${LIBDIR}/${CROSS} || { echo "❌ Failed to configure binutils in final"; exit 1; }

make MAKE=${MAKEOPT} || { echo "❌ Failed to build binutils in final"; exit 1; }

#####################################################
# Copy binutils binaries into package (final)
#####################################################
make install DESTDIR=${STAGEDIR} || { echo "❌ Failed to install binutils in final"; exit 1; }
make install DESTDIR=${BINUTILS_PKGDIR} || { echo "❌ Failed to install binutils in final"; exit 1; }
mkdir -p ${BINUTILS_PKGDIR}/usr/doc/${BINUTILS_PKG/binutils/binutils-${CROSS}}

cd ${SOURCEDIR}/${BINUTILS_PKG}

cp COPYING* ChangeLog MAINTAINERS README* ${BINUTILS_PKGDIR}/usr/doc/${BINUTILS_PKG/binutils/binutils-${CROSS}}

for TODO in ar as ld ld.bfd nm objcopy objdump ranlib readelf strip; do
	rm -f ${BINUTILS_PKGDIR}/usr/bin/${CROSS}-${TODO}
	ln -sf /usr/${CROSS}/bin/${TODO}  ${BINUTILS_PKGDIR}/usr/bin/${CROSS}-${TODO}
done

rm -f ${BINUTILS_PKGDIR}/usr/bin/${CROSS}-ld ${BINUTILS_PKGDIR}/usr/${CROSS}/bin/ld
ln -sf /usr/${CROSS}/bin/ld.bfd ${BINUTILS_PKGDIR}/usr/bin/${CROSS}-ld
ln -sf /usr/${CROSS}/bin/ld.bfd ${BINUTILS_PKGDIR}/usr/${CROSS}/bin/ld

#####################################################
# Construct the binutils package
#####################################################
find ${BINUTILS_PKGDIR}/usr/bin -type f -exec strip {} \;
find ${BINUTILS_PKGDIR}/usr/bin -type f -exec  chown root:root {} \;
find ${BINUTILS_PKGDIR}/usr/bin -type f -exec  chmod 0755 {} \;
find ${BINUTILS_PKGDIR}/usr/${CROSS}/bin -type f -exec strip {} \;
find ${BINUTILS_PKGDIR}/usr/${CROSS}/bin -type f -exec  chown root:root {} \;
find ${BINUTILS_PKGDIR}/usr/${CROSS}/bin -type f -exec  chmod 0755 {} \;
find ${BINUTILS_PKGDIR}/usr/man -type f -exec gzip {} \;
find ${BINUTILS_PKGDIR}/usr/info -type f -exec gzip {} \;

rm -f ${BINUTILS_PKGDIR}/usr/info/dir
( cd ${BINUTILS_PKGDIR}/usr/info; for TODO in *; do mv ${TODO} ${CROSS}-${TODO}; done )

#####################################################
# Build gcc from sources (final)
#####################################################
cd ${SOURCEDIR}/${GCC_PKG}/final

# Very ugly hack to make GCC find the Newlib includes
if [ -d "/usr/${CROSS}" ]; then
	mv /usr/${CROSS} /usr/${CROSS}.old
fi

ln -s ${STAGEDIR}/usr/${CROSS} /usr/${CROSS}

if [ -d "/usr/${CROSS}.old" ]; then
	mv /usr/${CROSS}.old /usr/${CROSS}
fi

CFLAGS="${CFLAGS}" CFLAGS_FOR_TARGET="-mlongcalls" CXXFLAGS_FOR_TARGET="-mlongcalls" ../configure ${GCC_BUILD} ${COMMON_BUILD} --disable-bootstrap --enable-languages="c,c++" --disable-lto  || { echo "❌ Failed to configure gcc in final"; exit 1; }

make MAKE=${MAKEOPT} all || { echo "❌ Failed to build gcc in final"; exit 1; }

#####################################################
# Copy gcc into package (final)
#####################################################
make install DESTDIR=${STAGEDIR} || { echo "❌ Failed to install gcc in final"; exit 1; }
make install DESTDIR=${GCC_PKGDIR} || { echo "❌ Failed to install gcc in final"; exit 1; }

# Revert ugly hack
if [ -L "/usr/${CROSS}" ]; then
	rm "/usr/${CROSS}"
fi

if [ -d "/usr/${CROSS}.old" ]; then
	mv /usr/${CROSS}.old /usr/${CROSS}
fi

mkdir -p ${GCC_PKGDIR}/usr/doc/${GCC_PKG/gcc/gcc-${CROSS}}

cd ${SOURCEDIR}/${GCC_PKG}

cp ABOUT-NLS COPYING* ChangeLog* LAST_UPDATED MAINTAINERS NEWS README ${GCC_PKGDIR}/usr/doc/${GCC_PKG/gcc/gcc-${CROSS}}
chown -R root:root ${GCC_PKGDIR}/usr/doc/${GCC_PKG/gcc/gcc-${CROSS}}/*
find ${GCC_PKGDIR}/usr/doc/${GCC_PKG/gcc/gcc-${CROSS}} -type d -exec chmod 0755 {} \;
find ${GCC_PKGDIR}/usr/doc/${GCC_PKG/gcc/gcc-${CROSS}} -type f -exec chmod 0644 {} \;

mv ${GCC_PKGDIR}/usr/bin/${CROSS}-g++ ${GCC_PKGDIR}/usr/bin/${CROSS}-${GXX_PKG}
rm -f ${GCC_PKGDIR}/usr/bin/${CROSS}-gcc ${GCC_PKGDIR}/usr/bin/${CROSS}-c++
ln -sf /usr/bin/${CROSS}-${GCC_PKG} $GCC_PKGDIR/usr/bin/${CROSS}-gcc
ln -sf /usr/bin/${CROSS}-${GXX_PKG} $GCC_PKGDIR/usr/bin/${CROSS}-g++
ln -sf /usr/bin/${CROSS}-${GXX_PKG} $GCC_PKGDIR/usr/bin/${CROSS}-c++

rm -rf ${GCC_PKGDIR}/usr/man/man7
rm -f ${GCC_PKGDIR}/usr/info/dir

# Disabled on purpose, the host CC provides
rm -f ${GCC_PKGDIR}/usr/${LIBDIR}/libcc1.*

#####################################################
# Construct the gcc package
#####################################################
find ${GCC_PKGDIR}/usr/bin -type f -exec strip {} \;
find ${GCC_PKGDIR}/usr/bin -type f -exec  chown root:root {} \;
find ${GCC_PKGDIR}/usr/bin -type f -exec  chmod 0755 {} \;
find ${GCC_PKGDIR}/usr/${CROSS}/bin -type f -exec strip {} \;
find ${GCC_PKGDIR}/usr/${CROSS}/bin -type f -exec  chown root:root {} \;
find ${GCC_PKGDIR}/usr/${CROSS}/bin -type f -exec  chmod 0755 {} \;
find ${GCC_PKGDIR}/usr/libexec/gcc/${CROSS}/${GCC_PKG#gcc-} -name '*.la' -prune -o -type f -exec strip {} \;
find ${GCC_PKGDIR}/usr/libexec/gcc/${CROSS}/${GCC_PKG#gcc-} -name '*.la' -prune -o -type f -exec  chown root:root {} \;
find ${GCC_PKGDIR}/usr/libexec/gcc/${CROSS}/${GCC_PKG#gcc-} -name '*.la' -prune -o -type f -exec  chmod 0755 {} \;
find ${GCC_PKGDIR}/usr/man -type f -exec gzip {} \;
find ${GCC_PKGDIR}/usr/info -type f -exec gzip {} \;

( cd ${GCC_PKGDIR}/usr/info; for TODO in *; do mv ${TODO} ${CROSS}-${TODO}; done )

for TODO in `find ${GCC_PKGDIR}/usr/man -type l -print`; do
	LINKTO=`readlink $TODO`
	rm $TODO
	ln -sf $LINKTO.gz $TODO.gz
done

for TODO in `find ${GCC_PKGDIR}/usr/info -type l -print`; do
	LINKTO=`readlink $TODO`
	rm $TODO
	ln -sf $LINKTO.gz $TODO.gz
done

#####################################################
# Move g++ into its own package
#####################################################
cd ${GCC_PKGDIR}
touch ${GXX_PKGDIR}/install/doinst.sh
chmod 755 ${GXX_PKGDIR}/install/doinst.sh
find . -type d -exec mkdir -p ${GXX_PKGDIR}/{} \;
find . \( -type f -o -type l \) \( -name '*++*' -o -name 'cc1plus' \) -exec mv {} ${GXX_PKGDIR}/{} \;
find . -type d -name '*++*' -exec rm -r {} \;
rm -r ${GXX_PKGDIR}/usr/doc
rm -rf ${GXX_PKGDIR}/usr/${PYTHONDIR}
mv usr/${PYTHONDIR} ${GXX_PKGDIR}/usr/${PYTHONDIR}

#####################################################
# Build newlib from sources (final)
#####################################################
cd ${SOURCEDIR}/${NEWLIB_PKG}/final
../configure ${NEWLIB_BUILD} ${COMMON_BUILD} --libdir=/usr/${LIBDIR}/${CROSS} CFLAGS_FOR_TARGET="-D__DYNAMIC_REENT__ -DHAVE_INITFINI_ARRAY=1 -I$PWD/../newlib/libc/machine/xtensa/include" || { echo "❌ Failed to configure newlib in final"; exit 1; }

make MAKE=${MAKEOPT} || { echo "❌ Failed to build newlib in final"; exit 1; }

#####################################################
# Copy newlib into package (final)
#####################################################
if [ "$LIBC_LIBRARY" == "newlib" ]; then
	make install DESTDIR=${STAGEDIR} || { echo "❌ Failed to install newlib in final"; exit 1; }
	make install DESTDIR=${NEWLIB_PKGDIR} || { echo "❌ Failed to install newlib in final"; exit 1; }
	mkdir -p ${NEWLIB_PKGDIR}/usr/doc/${NEWLIB_PKG}

	cd ${SOURCEDIR}/${NEWLIB_PKG}

	cp COPYING* ChangeLog* MAINTAINERS README* ${NEWLIB_PKGDIR}/usr/doc/${NEWLIB_PKG}
fi
####################################################
# Compiler verification by linking 
# against ESP NONOS SDK
# ##################################################

# PATH update
export PATH=/tmp/toolchain/binutils/usr/xtensa-lx106-elf/bin/:$PATH
# Verify compiler
echo "🔍 Verifying compiler..."
${GXX_PKGDIR}/usr/bin/xtensa-lx106-elf-gcc-g++-${GCC_VERSION} -v || { echo "❌ g++ not responding"; exit 1; }
echo 'extern "C" { void user_init(){} void user_pre_init(){} void call_user_start(){user_init();}}' > $SOURCEDIR/test.cpp
echo 'extern "C" { void* tkip = nullptr; void* wep = nullptr; }' > $SOURCEDIR/crypto_stubs.cpp
${GXX_PKGDIR}/usr/bin/xtensa-lx106-elf-gcc-g++-${GCC_VERSION}  -c  -std=c++23 -mlongcalls -mtext-section-literals $SOURCEDIR/test.cpp -o $SOURCEDIR/test.o || {
  echo "❌ Failed to compile C++23 test"; exit 1;
}
${GXX_PKGDIR}/usr/bin/xtensa-lx106-elf-gcc-g++-${GCC_VERSION}  -c  -std=c++23 -mlongcalls -mtext-section-literals $SOURCEDIR/crypto_stubs.cpp -o $SOURCEDIR/crypto_stubs.o || {
  echo "❌ Failed to compile C++23 crypto_stubs"; exit 1;
}
${GXX_PKGDIR}/usr/bin/xtensa-lx106-elf-gcc-g++-${GCC_VERSION}  $SOURCEDIR/test.o $SOURCEDIR/crypto_stubs.o  -I${ESP_SDK_PKGDIR}/opt/ESP8266_NONOS_SDK-${ESP_SDK_VERSION}/include -L${ESP_SDK_PKGDIR}/opt/ESP8266_NONOS_SDK-${ESP_SDK_VERSION}/lib -T${ESP_SDK_PKGDIR}/opt/ESP8266_NONOS_SDK-${ESP_SDK_VERSION}/ld/eagle.app.v6.ld -B${GCC_PKGDIR}/usr/${LIBDIR}/gcc/xtensa-lx106-elf/15.2.0/ -B${STAGEDIR}/usr/xtensa-lx106-elf/bin/ -B${STAGEDIR}/usr/xtensa-lx106-elf/lib/ -nostdlib -nodefaultlibs -nostartfiles -mlongcalls -mtext-section-literals -lmain -lpp -lnet80211 -llwip -lphy -lwpa -lcrypto -lssl -lhal -ldriver -ljson -lsmartconfig -lupgrade -lespnow -lairkiss -lat -lpwm -lstdc++ -lm -lc -lgcc -o $SOURCEDIR/test.elf || {
  echo "❌ Failed to link C++23 test"; exit 1;
}
#####################################################
# Create packages and package_descriptions
#####################################################
mkdir "${BINUTILS_PKGDIR}/DEBIAN"

# 📄 Control file: binutils
cat <<EOF > "${BINUTILS_PKGDIR}/DEBIAN/control"
Package: binutils-${CROSS}
Version: ${BINUTILS_VERSION//_/-}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Jose Gomez Lopez <jose.gomez.lopez@gmail.com>
Description: Binutils is a collection of binary utilities.  It includes 'as' (the portable GNU assembler), 'ld' (the GNU linker), and other utilities for creating and working with binary programs.  These utilities are REQUIRED to compile C, C++, Objective-C, Fortran, and most other programming languages.
EOF

# 📦 Generate package .deb: binutils
dpkg-deb --build "${BINUTILS_PKGDIR}" "${DEBIAN_PKG_DIR}/binutils-${CROSS}_${BINUTILS_VERSION}_${ARCH}.deb"

mkdir "${GCC_PKGDIR}/DEBIAN"

# 📄 Control file: gcc
cat <<EOF > "${GCC_PKGDIR}/DEBIAN/control"
Package: gcc-${CROSS}
Version: ${GCC_VERSION//_/-}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Jose Gomez Lopez <jose.gomez.lopez@gmail.com>
Description: GCC is the GNU Compiler Collection. This package contains those parts of the compiler collection needed to compile C code. Other packages add Ada, C++, Fortran, Go, Objective-C, and Java support to the compiler core.
EOF

# 📦 Generate package .deb: gcc
dpkg-deb --build "${GCC_PKGDIR}" "${DEBIAN_PKG_DIR}/gcc-${CROSS}_${GCC_VERSION}_${ARCH}.deb"

mkdir "${GXX_PKGDIR}/DEBIAN"

# 📄 Control file: g++
cat <<EOF > "${GXX_PKGDIR}/DEBIAN/control"
Package: g++-${CROSS}
Version: ${GXX_VERSION//_/-}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Jose Gomez Lopez <jose.gomez.lopez@gmail.com>
Description: C++ support for the GNU Compiler Collection. This package contains those parts of the compiler collection needed to compile C++ code. The base gcc package is also required.
EOF

# 📦 Generate package .deb: g++
dpkg-deb --build "${GXX_PKGDIR}" "${DEBIAN_PKG_DIR}/g++-${CROSS}_${GXX_VERSION}_${ARCH}.deb"

mkdir "${NEWLIB_PKGDIR}/DEBIAN"

# 📄 Control file: newlib
cat <<EOF > "${NEWLIB_PKGDIR}/DEBIAN/control"
Package: newlib-${CROSS}
Version: ${NEWLIB_VERSION//_/-}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Jose Gomez Lopez <jose.gomez.lopez@gmail.com>
Description: newlib-Newlib is a C library intended for use on embedded systems. It is a conglomeration of several library parts, all under free software licenses that make them easily usable on embedded products.  Newlib is only available in source form. It can be compiled for a wide array of processors, and will usually work on any architecture with the addition of a few low-level routines.
EOF

# 📦 Generate package .deb: newlib
dpkg-deb --build "${NEWLIB_PKGDIR}" "${DEBIAN_PKG_DIR}/newlib-${CROSS}_${NEWLIB_VERSION}_${ARCH}.deb"

mkdir "${ESP_SDK_PKGDIR}/DEBIAN"

# 📄 Control file: esp nonos sdk
cat <<EOF > "${ESP_SDK_PKGDIR}/DEBIAN/control"
Package: esp-sdk
Version: ${ESP_SDK_VERSION//_/-}
Section: devel
Priority: optional
Architecture: amd64
Maintainer: Jose Gomez Lopez <jose.gomez.lopez@gmail.com>
Description: ESP8266 SDK for creating binaries for the board.
EOF

# 📦 Generate package .deb: esp nonos sdk
dpkg-deb --build "${ESP_SDK_PKGDIR}" "${DEBIAN_PKG_DIR}/esp-sdk_${ESP_SDK_VERSION}_${ARCH}.deb"

#####################################################
# Cleanup
#####################################################
rm -rf $SOURCEDIR
