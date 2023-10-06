#!/bin/sh
#
# export PERL5LIB=/home/red/Downloads/linux-base-4.5ubuntu9/lib
# export PERL5LIB="/home/red/Downloads/debsums/dpkg-1.19.8/scripts/:/home/red/Downloads/linux-base-4.5ubuntu9/lib"
# export PATH=/home/red/Downloads/linux-base-4.5ubuntu9/bin:$PATH
export SHOW_LOG=yes
export SHOW_DEBUG=yes
export SHOW_COMMAND=yes
# export GITHUB_MIRROR=ghproxy
export GHCR_MIRROR=dockerproxy
./compile.sh build UBOOT_COMPILER=riscv64-unknown-linux-gnu- KERNEL_COMPILE=riscv64-unknown-linux-gnu- GITHUB_MIRROR=ghproxy REGIONAL_MIRROR=china BOARD=licheepi-4a BRANCH=legacy BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=yes RELEASE=jammy SKIP_EXTERNAL_TOOLCHAINS=no
