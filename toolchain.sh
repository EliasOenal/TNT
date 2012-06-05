#!/bin/bash
# Thumb2 Newlib Toolchain
# Written by Elias Önal <EliasOenal@gmail.com>, released as public domain.


set -e # abort on errors

GCC_URL="https://launchpad.net/gcc-linaro/4.7/4.7-2012.05/+download/gcc-linaro-4.7-2012.05.tar.bz2"
GCC_VERSION="gcc-linaro-4.7-2012.05"

NEWLIB_URL="ftp://sources.redhat.com/pub/newlib/newlib-1.20.0.tar.gz"
NEWLIB_VERSION="newlib-1.20.0"

BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/binutils-2.22.tar.gz"
BINUTILS_VERSION="binutils-2.22"

# Download
if [ ! -e ${GCC_VERSION}.tar.bz2 ]; then
curl -OL ${GCC_URL}
fi

if [ ! -e ${NEWLIB_VERSION}.tar.gz ]; then
curl -OL ${NEWLIB_URL}
fi

if [ ! -e ${BINUTILS_VERSION}.tar.gz ]; then
curl -OL ${BINUTILS_URL}
fi

# Extract
if [ ! -e ${GCC_VERSION} ]; then
tar -xf ${GCC_VERSION}.tar.bz2
fi

if [ ! -e ${NEWLIB_VERSION} ]; then
tar -xf ${NEWLIB_VERSION}.tar.gz
fi

if [ ! -e ${BINUTILS_VERSION} ]; then
tar -xf ${BINUTILS_VERSION}.tar.gz
fi


TARGET=arm-none-eabi
PREFIX=$HOME/toolchain
export PATH=$PATH:${PREFIX}/bin

#OSX workarounds
DARWIN_OPT_PATH=/opt/local
export CC=gcc

DARWIN_LIBS="--with-gmp=${DARWIN_OPT_PATH} \
		--with-mpfr=${DARWIN_OPT_PATH} \
		--with-mpc=${DARWIN_OPT_PATH} \
		--with-libiconv-prefix=${DARWIN_OPT_PATH}"

#newlib
NEWLIB_FLAGS="--target=${TARGET} \
		--prefix=${PREFIX} \
		--with-build-time-tools=${PREFIX}/bin \
		--with-sysroot=${PREFIX}/${TARGET} \
		--disable-shared \
		--disable-newlib-supplied-syscalls"


# split functions into small sections for link time garbage collection
# split data into sections as well
# tell gcc to optimize for size
# we don't need a frame pointer -> one more register :)
# never unroll loops
# arm procedure call standard, probably also done without this
# tell newlib to prefer small code...
# ...again
# optimize malloc for small ram (128 byte pages instead of 4096)
# tell newlib to use 256byte buffers instead of 1024
OPTIMIZE="-ffunction-sections \
	-fdata-sections \
	-Os \
	-fomit-frame-pointer \
	-fno-unroll-loops \
	-mabi=aapcs \
	-DPREFER_SIZE_OVER_SPEED \
	-D__OPTIMIZE_SIZE__ \
	-DSMALL_MEMORY \
	-D__BUFSIZ__=256"

#gcc flags
# newlib :)
# static linking for uber huge binaries
# that's our cortex-m3
# speaking thumb2
# no fpu for my cortex-m3
# we don't care about gcc translations
# prevent accidentally linking x86er/host libs
# lib stack smashing protection fails to build for our target (probably related to newlib)
# link time optimizations
# debugging lib
# openMP
# pch
# exceptions (?)

GCCFLAGS="--target=${TARGET} \
	--prefix=${PREFIX} \
	--with-newlib \
	${DARWIN_LIBS} \
	--with-build-time-tools=${PREFIX}/${TARGET}/bin \
	--with-sysroot=${PREFIX}/${TARGET} \
	--disable-shared \
	--with-arch=armv7-m \
	--with-mode=thumb \
	--with-float=soft \
	--disable-nls \
	--enable-poison-system-directories \
	--enable-lto \
	--disable-libmudflap \
	--disable-libgomp \
	--disable-libstdcxx-pch \
	--disable-libunwind-exceptions"

# only build c the first time
GCCFLAGS_ONE="--without-headers --enable-languages=c"

# now c++ as well
GCCFLAGS_TWO="--enable-languages=c,c++ --disable-libssp"

if [ ! -e build-binutils ]; then

mkdir build-binutils
cd build-binutils
../${BINUTILS_VERSION}/configure --target=${TARGET} --prefix=${PREFIX} --with-sysroot=${PREFIX}/${TARGET} --disable-nls
make all -j2
make install
cd ..

fi


if [ ! -e build-gcc ]; then

mkdir build-gcc
cd build-gcc
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_ONE}
make all-gcc -j2 CFLAGS_FOR_TARGET="${OPTIMIZE}"
make install-gcc
cd ..

fi


if [ ! -e build-newlib ]; then

mkdir build-newlib
cd build-newlib
../${NEWLIB_VERSION}/configure ${NEWLIB_FLAGS}
make all -j2 CFLAGS_FOR_TARGET="${OPTIMIZE}" CCASFLAGS="${OPTIMIZE}"
make install
cd ..

fi


cd build-gcc
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_TWO}
make all -j2 CFLAGS_FOR_TARGET="${OPTIMIZE}"
make install
cd ..

if [ ! -e build-gdb ]; then
echo "Building GDB"
#mkdir build-gdb
#cd build-gdb
#../gdb-7.3.1/configure --target=$TARGET --prefix=$PREFIX
#make all
#make install
fi
