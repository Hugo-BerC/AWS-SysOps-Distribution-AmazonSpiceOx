#!/usr/bin/env sh
set -eu

kernel_src="${1:?kernel source directory required}"
sysroot_dir="${2:?sysroot directory required}"
kernel_arch="${3:?kernel arch required}"

echo "Preparing toolchain sysroot at $sysroot_dir"

mkdir -p "$sysroot_dir/usr"
mkdir -p "$sysroot_dir/usr/include"
rm -rf \
    "$sysroot_dir/usr/include/linux" \
    "$sysroot_dir/usr/include/asm" \
    "$sysroot_dir/usr/include/asm-generic"

# Phase IV starts by defining a controlled userspace/kernel ABI boundary.
# Kernel headers go into sysroot/usr/include so later libc and compiler stages
# can target AmazonSpiceOx without relying on host headers.
make -C "$kernel_src" \
    ARCH="$kernel_arch" \
    INSTALL_HDR_PATH="$sysroot_dir/usr" \
    headers_install

mkdir -p "$sysroot_dir/usr/lib" "$sysroot_dir/lib" "$sysroot_dir/usr/bin"
touch "$sysroot_dir/.headers-stamp"

echo "Toolchain sysroot ready: $sysroot_dir"
