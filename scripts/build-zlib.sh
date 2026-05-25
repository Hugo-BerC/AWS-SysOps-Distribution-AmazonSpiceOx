#!/usr/bin/env sh
set -eu

zlib_src="${1:?zlib source directory required}"
build_dir="${2:?zlib build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building zlib for $target"

zlib_src="$(cd "$zlib_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"

cross_cc="$prefix_dir/bin/$target-gcc --sysroot=$sysroot_dir"
cross_ar="$prefix_dir/bin/$target-ar"
cross_ranlib="$prefix_dir/bin/$target-ranlib"

# zlib's build system is intentionally small and in-tree. Copying the source
# into a throwaway build directory keeps the original unpacked tree pristine
# while still matching zlib's preferred configure flow.
cp -a "$zlib_src/." "$build_dir/"

cd "$build_dir"

CHOST="$target" \
CC="$cross_cc" \
AR="$cross_ar" \
RANLIB="$cross_ranlib" \
./configure --prefix=/usr --static

make -j"$jobs"
make install DESTDIR="$sysroot_dir"

echo "zlib installed into $sysroot_dir"
