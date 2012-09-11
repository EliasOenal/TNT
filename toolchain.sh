#!/usr/bin/env bash
# Thumb2 Newlib Toolchain
# Written by Elias Önal <EliasOenal@gmail.com>, released as public domain.

GCC_URL="https://launchpad.net/gcc-linaro/4.7/4.7-2012.08/+download/gcc-linaro-4.7-2012.08.tar.bz2"
GCC_VERSION="gcc-linaro-4.7-2012.08"

#GCC_URL="ftp://gcc.gnu.org/pub/gcc/snapshots/4.8-20120610/gcc-4.8-20120610.tar.bz2"
#GCC_VERSION="gcc-4.8-20120610"

NEWLIB_URL="ftp://sources.redhat.com/pub/newlib/newlib-1.20.0.tar.gz"
NEWLIB_VERSION="newlib-1.20.0"

BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/binutils-2.22.tar.gz"
BINUTILS_VERSION="binutils-2.22"

GDB_URL="http://ftp.gnu.org/gnu/gdb/gdb-7.4.1.tar.gz"
GDB_VERSION="gdb-7.4.1"

set -e # abort on errors

OS_TYPE=$(uname)

# locate the tools
if [[ `which curl` ]]; then
FETCH="curl -kOL"
elif [[ `which wget` ]]; then
FETCH="wget -c --no-check-certificate "
else
echo "Neither curl or wget located."
exit
fi

if [[ `which gtar` ]]; then
TAR=gtar
elif [[ `which tar` ]]; then
TAR=tar
else
echo "tar required."
exit
fi

if [[ `which gmake` ]]; then
MAKE=gmake
elif [[ `which make` ]]; then
MAKE=make
else
echo "make required."
exit
fi

# Download
if [ ! -e ${GCC_VERSION}.tar.bz2 ]; then
${FETCH} ${GCC_URL}
fi

if [ ! -e ${NEWLIB_VERSION}.tar.gz ]; then
${FETCH} ${NEWLIB_URL}
fi

if [ ! -e ${BINUTILS_VERSION}.tar.gz ]; then
${FETCH} ${BINUTILS_URL}
fi

if [ ! -e ${GDB_VERSION}.tar.gz ]; then
${FETCH} ${GDB_URL}
fi

# Extract
if [ ! -e ${GCC_VERSION} ]; then
${TAR} -xf ${GCC_VERSION}.tar.bz2
patch -N ${GCC_VERSION}/gcc/config/arm/t-arm-elf gcc-multilib.patch
fi

if [ ! -e ${NEWLIB_VERSION} ]; then
${TAR} -xf ${NEWLIB_VERSION}.tar.gz
patch -N ${NEWLIB_VERSION}/libgloss/arm/linux-crt0.c newlib-optimize.patch
fi

if [ ! -e ${BINUTILS_VERSION} ]; then
${TAR} -xf ${BINUTILS_VERSION}.tar.gz
fi

if [ ! -e ${GDB_VERSION} ]; then
${TAR} -xf ${GDB_VERSION}.tar.gz
fi

# Configure (to the operating system)
TARGET=arm-none-eabi
PREFIX="$HOME/toolchain"
CPUS=2
export PATH="${PREFIX}/bin:${PATH}"
export CC=gcc

case "$OS_TYPE" in
    "Linux" )
    OPT_PATH=""
    ;;
    "NetBSD" )
    OPT_PATH=/usr/local
    ;;
    "Darwin" )
    OPT_PATH=/opt/local
    ;;
    * )
    echo "OS entry needed at line 100 of this script."
    exit
esac

if [ "$OPT_PATH" == "" ]; then
OPT_LIBS=""
else
OPT_LIBS="--with-gmp=${OPT_PATH} \
	--with-mpfr=${OPT_PATH} \
	--with-mpc=${OPT_PATH} \
	--with-libiconv-prefix=${OPT_PATH}"
fi




#newlib
NEWLIB_FLAGS="--target=${TARGET} \
		--prefix=${PREFIX} \
		--with-build-time-tools=${PREFIX}/bin \
		--with-sysroot=${PREFIX}/${TARGET} \
		--disable-shared \
		--disable-newlib-supplied-syscalls \
		--enable-newlib-reent-small \
		--enable-target-optspace \
		--enable-multilib \
		--enable-interwork"


# split functions into small sections for link time garbage collection
# split data into sections as well
# tell gcc to optimize for size
# we don't need a frame pointer -> one more register :)
# never unroll loops
# arm procedure call standard, probably also done without this
# tell newlib to prefer small code...
# ...again
# optimize sbrk for small ram (128 byte pages instead of 4096)
# tell newlib to use 128byte buffers instead of 1024

#	-D_REENT_SMALL \
#-flto -fuse-linker-plugin 
OPTIMIZE="-ffunction-sections \
	-fdata-sections \
	-Os \
	-lto \
	-fomit-frame-pointer \
	-fno-unroll-loops \
	-mabi=aapcs \
	-DPREFER_SIZE_OVER_SPEED \
	-D__OPTIMIZE_SIZE__ \
	-DSMALL_MEMORY \
	-D__BUFSIZ__=128 \
	-D_REENT_SMALL"

# -fuse-linker-plugin
OPTIMIZE_LD="-Os -flto"

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
	${OPT_LIBS} \
	--with-build-time-tools=${PREFIX}/${TARGET}/bin \
	--with-sysroot=${PREFIX}/${TARGET} \
	--disable-shared \
	--enable-multilib \
	--enable-interwork \
	--disable-nls \
	--enable-poison-system-directories \
	--enable-lto \
	--enable-gold \
	--disable-libmudflap \
	--disable-libgomp \
	--disable-libstdcxx-pch \
	--disable-libunwind-exceptions"

# only build c the first time
GCCFLAGS_ONE="--without-headers --enable-languages=c"

# now c++ as well
GCCFLAGS_TWO="--enable-languages=c,c++ --disable-libssp"


if [ ! -e build-binutils.complete ]; then

mkdir build-binutils
cd build-binutils
../${BINUTILS_VERSION}/configure --target=${TARGET} --prefix=${PREFIX} \
        --with-sysroot=${PREFIX}/${TARGET} --disable-nls --enable-gold \
        --enable-plugins --enable-lto --disable-werror --enable-multilib --enable-interwork
${MAKE} all -j${CPUS}
${MAKE} install
cd ..
touch build-binutils.complete

else

cd build-binutils
${MAKE} install
cd ..

fi


if [ ! -e build-gcc.complete ]; then

mkdir build-gcc
cd build-gcc
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_ONE}
${MAKE} all-gcc -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" \
    LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"
${MAKE} install-gcc
cd ..
touch build-gcc.complete

fi


if [ ! -e build-newlib.complete ]; then

mkdir build-newlib
cd build-newlib
../${NEWLIB_VERSION}/configure ${NEWLIB_FLAGS}

# Use "_REENT_INIT_PTR()" for reentrancy
#-DREENTRANT_SYSCALLS_PROVIDED \
#		-DMISSING_SYSCALL_NAMES -D__DYNAMIC_REENT__
${MAKE} all -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"

${MAKE} install
cd ..
touch build-newlib.complete

else

cd build-newlib
${MAKE} install
cd ..

fi


if [ ! -e build2-gcc.complete ]; then

cd build-gcc
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_TWO}
${MAKE} all -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" \
    LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"
${MAKE} install
cd ..
touch build2-gcc.complete

else

cd build-gcc
${MAKE} install
cd ..

fi


if [ ! -e build-gdb.complete ]; then

mkdir build-gdb
cd build-gdb
../${GDB_VERSION}/configure --enable-multilib --enable-interwork --target=$TARGET --prefix=$PREFIX
${MAKE} all -j${CPUS}
${MAKE} install
cd ..
touch build-gdb.complete

else

cd build-gdb
${MAKE} install
cd ..

fi
