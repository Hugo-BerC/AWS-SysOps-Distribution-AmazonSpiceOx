#!/usr/bin/env sh
set -eu

openssl_src="${1:?OpenSSL source directory required}"
build_dir="${2:?OpenSSL build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building OpenSSL for $target"

openssl_src="$(cd "$openssl_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"

cross_prefix="$prefix_dir/bin/$target-"
cross_cc="$prefix_dir/bin/$target-gcc"
cross_ar="$prefix_dir/bin/$target-ar"
cross_ranlib="$prefix_dir/bin/$target-ranlib"

# OpenSSL's build remains easiest to reason about when configured from a full
# source tree. Copying into a throwaway build directory keeps the unpacked
# source pristine while still using OpenSSL's native Configure flow.
cp -a "$openssl_src/." "$build_dir/"

cd "$build_dir"

CC="$cross_cc" \
AR="$cross_ar" \
RANLIB="$cross_ranlib" \
CFLAGS="--sysroot=$sysroot_dir -Os" \
perl ./Configure \
    linux-x86_64 \
    --cross-compile-prefix="$cross_prefix" \
    --prefix=/usr \
    --openssldir=/etc/ssl \
    --libdir=lib \
    no-docs \
    no-module \
    no-shared \
    no-tests \
    no-asm

make -j"$jobs"
make install_sw DESTDIR="$sysroot_dir"

echo "OpenSSL installed into $sysroot_dir"
