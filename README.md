# Thumb2 Newlib Toolchain
This is the Thumb2 Newlib Toolchain project providing a script to compile the latest GCC with Newlib and optimizations for microcontrollers.


So far it has been tested on MacOS, (including on ARM64/M1) Debian, Ubuntu and NetBSD, feel free to push changes for your OS.


# Dependencies

Build dependencies on Ubuntu:
```
apt install build-essential gcc gdb binutils libmpfr6 libmpfr-dev libgmp-dev libgmp10 libmpc-dev libmpc3
apt build-dep gdb binutils
```


# Building

Usage is quite simple:
* Execute "./toolchain.sh" to build toolchain
* Execute "./toolchain.sh clean" to remove build artefacts
* Check script header for configuration options


# Changes

* 05/22/2022 - GDB 12.1, added GMP 
* 04/11/2022 — Downgraded GDB to version 10.2 due to regressions in 11.2.
* 03/26/2022 — GCC 11.2.0, Newlib 4.1.0, binutils 2.38 and GDB 11.2.
* 11/17/2020 — GCC 10.2.0, binutils 2.35.1 and GDB 10.1.
* 02/03/2020 — GCC 9.2.0, Newlib 3.3.0, binutils 2.33.1 and GDB 8.3.
* 09/19/2018 — GCC 8.2
* 01/30/2018 — GCC 7.3, Newlib 3.0.0 etc. Support for Cortex-M7 including VFPU. (fpv5-d16 and fpv5-sp-d16)
               Default code size optimizations and buffer sizes are now less aggressive. (Can still be configured)
* 02/10/2017 — GCC 6.3, Newlib 2.5.0 etc. New option to enable Newlib instrumentation.
* 02/29/2016 — GCC 5.3 and Newlib 2.3.0 as well as compilation with debug symbols.
* 09/18/2015 — GCC 5.2 and the latest Newlib 2.2.0
* 03/19/2014 — The latest everything. GCC 4.9 (snapshot), Newlib 2.1.0 (nano-malloc) and more!
* 08/24/2013 — Additional optimization option preferring speed over size
* 01/24/2013 — Replaced newlib with newlib-nano, the newlib option is still in the build script.
* 06/05/2012 — TNT has been updated to the latest Linaro GCC 4.7
* 06/22/2012 — Switched to a GCC 4.8 snapshot and disabled LTO for newlib due to regressions
* 08/29/2012 — Switched to the latest Linaro GCC for minor size improvements, also configured newlib with "reent-small" for 800byte savings in .data
* 09/10/2012 — Multilib support for several thumb targets: armv6s-m (cortex-m0/cortex-m1) armv7-m (cortex-m3) armv7e-m (cortex-m4/cortex-m4f including FPU and DSP instruction support)
