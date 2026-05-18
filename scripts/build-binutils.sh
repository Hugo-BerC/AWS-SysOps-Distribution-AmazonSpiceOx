#!/usr/bin/env sh
set -eu

binutils_src="${1:?binutils source directory required}"
build_dir="${2:?binutils build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building cross-binutils for $target"

binutils_src="$(cd "$binutils_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir" "$prefix_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"

cd "$build_dir"

# Release tarballs should already carry generated files, so MAKEINFO=true keeps
# the build light and avoids requiring texinfo for this bootstrap step.
"$binutils_src/configure" \
    --target="$target" \
    --prefix="$prefix_dir" \
    --with-sysroot="$sysroot_dir" \
    --disable-nls \
    --disable-multilib \
    --disable-werror \
    --enable-deterministic-archives

make -j"$jobs" MAKEINFO=true
make install MAKEINFO=true

echo "Cross-binutils ready under $prefix_dir/bin"
