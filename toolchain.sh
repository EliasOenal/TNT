#!/usr/bin/env bash
# Thumb2 Newlib Toolchain
# Written and placed into the public domain by
# Elias Oenal <tnt@eliasoenal.com>
#
# Execute "./toolchain.sh" to build toolchain
# Execute "./toolchain.sh clean" to remove build artefacts

# re-install compiled components
#DO_REINSTALLS=true

# When the goal is minimum flash size
# (This may cost additional RAM)
#SIZE_OVER_SPEED=true

# Nano malloc
# Optimised for systems with tiny amounts of RAM.
# This implementation has issues joining freed segments.
#NANO_MALLOC=true

# Debug symbols, allows debugging of C library
DEBUG_SYMBOLS=true

# Use newlib-nano-1.0
#NANO=true

# C++ support
#BUILD_CPP=true

# GNU Debugger
#BUILD_GDB=true

# Insight graphical GDB interface
#BUILD_INSIGHT=true

# Utility to support debugger with the same name
#BUILD_STLINK=true

# Size of buffers used by newlib, should be at least 64 bytes.
# Lowe values save RAM, yet significantly slow down IO.
# This can selectively be overridden using setbuff(). 
BUFFSIZ=1024

# Parallel build
CPUS=4

# Uncomment to enable instrumentation calls to newlib (can be used with gprof)
#NEWLIB_PROFILING="-pg"

TARGET=arm-none-eabi

PREFIX="$HOME/toolchain"

export PATH="${PREFIX}/bin:${PATH}"
export CC=gcc
export CXX=g++

GCC_URL="https://ftp.gnu.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz"
GCC_VERSION="gcc-12.2.0"

if [ -n "$NANO" ]; then
NEWLIB_URL="http://eliasoenal.com/newlib-nano-1.0.tar.bz2"
NEWLIB_VERSION="newlib-nano-1.0"
else
NEWLIB_URL="https://sourceware.org/pub/newlib/newlib-4.1.0.tar.gz"
NEWLIB_VERSION="newlib-4.1.0"
fi

BINUTILS_URL="https://ftp.gnu.org/gnu/binutils/binutils-2.38.tar.xz"
BINUTILS_VERSION="binutils-2.38"

GDB_URL="https://ftp.gnu.org/gnu/gdb/gdb-12.1.tar.xz"
GDB_VERSION="gdb-12.1"

GMP_URL="https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz"
GMP_VERSION="gmp-6.2.1"

STLINK_REPOSITORY="git://github.com/texane/stlink.git"
STLINK="stlink"

INSIGHT_URL="ftp://sourceware.org/pub/insight/releases/insight-6.8-1a.tar.bz2"
INSIGHT_VERSION="insight-6.8-1a"
INSIGHT_FOLDER="insight-6.8-1"

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

if [ "$1" == "clean" ]; then
	echo "cleaning up."
	rm -rf build-*
	exit
fi

# Download
if [ ! -e ${GCC_VERSION}.tar.xz ]; then
${FETCH} ${GCC_URL}
fi


if [ -n "$NANO" ]; then
if [ ! -e ${NEWLIB_VERSION}.tar.bz2 ]; then
${FETCH} ${NEWLIB_URL}
fi
else
if [ ! -e ${NEWLIB_VERSION}.tar.gz ]; then
${FETCH} ${NEWLIB_URL}
fi
fi


if [ ! -e ${BINUTILS_VERSION}.tar.xz ]; then
${FETCH} ${BINUTILS_URL}
fi


if [ ! -e ${GMP_VERSION}.tar.xz ]; then
${FETCH} ${GMP_URL}
fi


if [ -n "$BUILD_GDB" ]; then
if [ ! -e ${GDB_VERSION}.tar.xz ]; then
${FETCH} ${GDB_URL}
fi
fi

if [ -n "$BUILD_STLINK" ]; then
if [ ! -e ${STLINK} ]; then
git clone ${STLINK_REPOSITORY}
fi
fi

if [ -n "$BUILD_INSIGHT" ]; then
if [ ! -e ${INSIGHT_VERSION}.tar.bz2 ]; then
${FETCH} ${INSIGHT_URL}
fi
fi

# Extract
if [ ! -e ${GCC_VERSION} ]; then
${TAR} -xf ${GCC_VERSION}.tar.xz
patch -N ${GCC_VERSION}/gcc/config/arm/t-arm-elf gcc-multilib-12.patch
patch -N ${GCC_VERSION}/gcc/config.host gcc-macos-arm64.patch # Workaround for GCC builds on MacOS ARM64
fi

if [ ! -e ${NEWLIB_VERSION} ]; then
if [ -n "$NANO" ]; then
${TAR} -xf ${NEWLIB_VERSION}.tar.bz2
else
${TAR} -xf ${NEWLIB_VERSION}.tar.gz
fi

if [ -n "$NANO" ]; then
patch -N ${NEWLIB_VERSION}/libgloss/arm/linux-crt0.c newlib-optimize.patch
else
patch -N ${NEWLIB_VERSION}/libgloss/arm/linux-crt0.c newlib-optimize.patch
# LTO patch for newlib
#patch -N ${NEWLIB_VERSION}/newlib/libc/machine/arm/arm_asm.h newlib-lto.patch
#fix regression in 2.1.0
#patch -N ${NEWLIB_VERSION}/libgloss/arm/cpu-init/Makefile.in newlib-2.1.0_libgloss_regression.patch
fi

fi

if [ ! -e ${BINUTILS_VERSION} ]; then
${TAR} -xf ${BINUTILS_VERSION}.tar.xz
fi


if [ ! -e ${GMP_VERSION} ]; then
${TAR} -xf ${GMP_VERSION}.tar.xz
fi


if [ -n "$BUILD_GDB" ]; then
if [ ! -e ${GDB_VERSION} ]; then
${TAR} -xf ${GDB_VERSION}.tar.xz
fi
fi

if [ -n "$BUILD_INSIGHT" ]; then
if [ ! -e ${INSIGHT_FOLDER} ]; then
${TAR} -xf ${INSIGHT_VERSION}.tar.bz2
fi
fi

case "$OS_TYPE" in
    "Linux" )
    OPT_PATH=""
    ;;
    "NetBSD" )
    OPT_PATH=/usr/local
    ;;
    "Darwin" )
	# using gcc from macports
    export CC=gcc-mp-12
    export CXX=g++-mp-12
    OPT_PATH=/opt/local
    ;;
    * )
    echo "OS entry needed at line ${LINENO} of this script."
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


if [ -n "$SIZE_OVER_SPEED" ]; then
SIZE_VS_SPEED_NEWLIB="--enable-target-optspace \
            --enable-newlib-reent-small"
else
SIZE_VS_SPEED_NEWLIB=""
fi

if [ -n "$DEBUG_SYMBOLS" ]; then
DEBUG_FLAGS="-g"
else
DEBUG_FLAGS=""
fi

#newlib
if [ -n "$NANO_MALLOC" ]; then
NEWLIB_NANO_MALLOC="--enable-newlib-nano-malloc"
else
NEWLIB_NANO_MALLOC=""
fi

NEWLIB_FLAGS="--target=${TARGET} \
			--prefix=${PREFIX} \
			${SIZE_VS_SPEED_NEWLIB} \
			--with-build-time-tools=${PREFIX}/bin \
			--with-sysroot=${PREFIX}/${TARGET} \
			--disable-shared \
			--disable-newlib-supplied-syscalls \
			--enable-multilib \
			--enable-interwork \
			${NEWLIB_NANO_MALLOC} \
        	--enable-newlib-io-c99-formats \
			--enable-newlib-io-long-long \
        	--enable-lto"

if [ -n "$SIZE_OVER_SPEED" ]; then
SIZE_VS_SPEED_OPTIMIZE="-Os \
			${DEBUG_FLAGS} \
			-DPREFER_SIZE_OVER_SPEED \
			-D__OPTIMIZE_SIZE__ \
			-D_REENT_SMALL \
			-fno-unroll-loops"
else
SIZE_VS_SPEED_OPTIMIZE="-Os \
			${DEBUG_FLAGS}"
fi

# -ffunction-sections split functions into small sections for link time garbage collection
# -fdata-sections split data into sections as well
# -Os tell gcc to optimize for size
# -fomit-frame-pointer we don't need a frame pointer -> one more register :)
# -fno-unroll-loops never unroll loops
# -mabi=aapcs arm procedure call standard, probably also done without this
# -DPREFER_SIZE_OVER_SPEED tell newlib to prefer small code...
# -D__OPTIMIZE_SIZE__ ...again
# -DSMALL_MEMORY optimize sbrk for small ram (128 byte pages instead of 4096)
# -D__BUFSIZ__=64 tell newlib to use 64byte buffers instead of 1024
# -D_STDIO_BSD_SEMANTICS optimize fflush()

OPTIMIZE="-ffunction-sections \
			-fdata-sections \
			-mabi=aapcs \
			${SIZE_VS_SPEED_OPTIMIZE} \
			-DSMALL_MEMORY \
			-D_STDIO_BSD_SEMANTICS \
			-D__BUFSIZ__=${BUFFSIZ} \
			-ffast-math \
			-ftree-vectorize"

#	-fomit-frame-pointer \
#-flto -fuse-linker-plugin # Everything goes into .text and gets discarded :/

#  -flto -fuse-linker-plugin
OPTIMIZE_LD="${OPTIMIZE}"

#gcc flags
# --with-newlib -> newlib :)
# --disable-shared static linking for uber huge binaries
# --enable-poison-system-directories prevent accidentally linking x86er/host libs
# --disable-libssp lib stack smashing protection fails to build for our target (probably related to newlib)
# --enable-lto link time optimizations

GCCFLAGS="--target=${TARGET} \
			--prefix=${PREFIX} \
			--with-newlib \
			${OPT_LIBS} \
			--with-build-time-tools=${PREFIX}/${TARGET}/bin \
			--with-sysroot=${PREFIX}/${TARGET} \
			--disable-shared \
			--enable-interwork \
			--disable-nls \
			--enable-poison-system-directories \
			--enable-lto \
			--enable-gold \
			--disable-libmudflap \
			--disable-libgomp \
			--disable-libstdcxx-pch \
			--disable-libssp \
			--disable-tls \
			--disable-threads \
			--disable-libunwind-exceptions \
			--enable-checking=release"

# only build c the first time
GCCFLAGS_ONE="--without-headers --enable-languages=c"

# now c++ as well
GCCFLAGS_TWO="--enable-languages=c,c++ --disable-libssp"


if [ -n "$BUILD_INSIGHT" ]; then
if [ ! -e build-insight.complete ]; then

mkdir -p build-insight
cd build-insight
../${INSIGHT_FOLDER}/configure ${OPT_LIBS} --disable-werror --enable-multilib --enable-interwork --target=$TARGET --prefix=$PREFIX
${MAKE} -j${CPUS}
${MAKE} install
cd ..
touch build-insight.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-insight
${MAKE} install
cd ..

fi
fi


if [ ! -e build-binutils.complete ]; then

mkdir -p build-binutils
cd build-binutils
../${BINUTILS_VERSION}/configure --target=${TARGET} --prefix=${PREFIX} \
        --with-sysroot=${PREFIX}/${TARGET} --disable-nls --enable-gold \
        --enable-plugins --enable-lto --disable-werror --enable-multilib --enable-interwork
${MAKE} all -j${CPUS}
${MAKE} install
cd ..
touch build-binutils.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-binutils
${MAKE} install
cd ..

fi


if [ ! -e build-gcc.complete ]; then

mkdir -p build-gcc
cd build-gcc
# There seems to be a regression that requires GCC to build with -j1 for 4.9.2 (Tested on OSX)
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_ONE}
${MAKE} all-gcc -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" \
    LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"
${MAKE} all-target-libgcc -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" \
    LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"
${MAKE} install-gcc
${MAKE} install-target-libgcc
cd ..
touch build-gcc.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-gcc
${MAKE} install-gcc
${MAKE} install-target-libgcc
cd ..

fi


if [ ! -e build-newlib.complete ]; then

mkdir -p build-newlib
cd build-newlib
../${NEWLIB_VERSION}/configure ${NEWLIB_FLAGS}

${MAKE} all -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE} ${NEWLIB_PROFILING}" LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"

${MAKE} install
cd ..
touch build-newlib.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-newlib
${MAKE} install
cd ..

fi


if [ -n "$BUILD_CPP" ]; then
if [ ! -e build2-gcc.complete ]; then

cd build-gcc
../${GCC_VERSION}/configure ${GCCFLAGS} ${GCCFLAGS_TWO}
${MAKE} all -j${CPUS} CFLAGS_FOR_TARGET="${OPTIMIZE}" \
    LDFLAGS_FOR_TARGET="${OPTIMIZE_LD}"
${MAKE} install
cd ..
touch build2-gcc.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-gcc
${MAKE} install
cd ..

fi
fi



if [ ! -e build-gmp.complete ]; then

mkdir -p build-gmp
cd build-gmp
../${GMP_VERSION}/configure --prefix=$PREFIX
${MAKE} all -j${CPUS}
${MAKE} install
cd ..
touch build-gmp.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd build-gmp
${MAKE} install
cd ..

fi


if [ -n "$BUILD_GDB" ]; then
if [ ! -e build-gdb.complete ]; then

mkdir -p build-gdb
cd build-gdb
../${GDB_VERSION}/configure --enable-multilib --enable-interwork --enable-sim --enable-sim-stdio --target=$TARGET --prefix=$PREFIX
${MAKE} all -j${CPUS}
${MAKE} install
cd ..
touch build-gdb.complete


elif [ -n "$DO_REINSTALLS" ]; then

cd build-gdb
${MAKE} install
cd ..

fi
fi

if [ -n "$BUILD_STLINK" ]; then
if [ ! -e build-stlink.complete ]; then

cd stlink
./autogen.sh
cd ..
mkdir -p build-stlink
cd build-stlink
../stlink/configure --prefix=$PREFIX
${MAKE} -j${CPUS}
${MAKE} install
cd ..
touch build-stlink.complete

elif [ -n "$DO_REINSTALLS" ]; then

cd stlink
${MAKE} install
cd ..

fi
fi

echo ""
echo "###########################"
echo "# Succeeded building TNT! #"
echo "###########################"
