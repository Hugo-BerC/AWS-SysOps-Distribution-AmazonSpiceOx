#!/usr/bin/env sh
set -eu

musl_src="${1:?musl source directory required}"
build_dir="${2:?musl build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building musl for $target"

musl_src="$(cd "$musl_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"
export PATH="$prefix_dir/bin:$PATH"

cross_cc="$prefix_dir/bin/$target-gcc"
cross_ar="$prefix_dir/bin/$target-ar"
cross_ranlib="$prefix_dir/bin/$target-ranlib"

cd "$build_dir"

# musl becomes the first real libc in the AmazonSpiceOx sysroot. We install it
# under /usr and /lib inside DESTDIR=sysroot so later GCC stages can treat the
# sysroot like a normal target filesystem.
CC="$cross_cc" \
AR="$cross_ar" \
RANLIB="$cross_ranlib" \
"$musl_src/configure" \
    --target="$target" \
    --prefix=/usr \
    --syslibdir=/lib

make -j"$jobs"
make DESTDIR="$sysroot_dir" install

echo "musl installed into $sysroot_dir"
