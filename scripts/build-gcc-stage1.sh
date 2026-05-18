#!/usr/bin/env sh
set -eu

gcc_src="${1:?gcc source directory required}"
build_dir="${2:?gcc build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building GCC stage 1 for $target"

gcc_src="$(cd "$gcc_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir" "$prefix_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"
export PATH="$prefix_dir/bin:$PATH"

cd "$build_dir"

# Stage 1 builds the freestanding C cross-compiler plus the minimal target
# libgcc pieces that libc needs for compiler builtins such as complex math
# helpers. `--with-newlib` keeps GCC in a libc-light bootstrap mode so this can
# happen before musl has populated the target headers.
"$gcc_src/configure" \
    --target="$target" \
    --prefix="$prefix_dir" \
    --with-sysroot="$sysroot_dir" \
    --with-native-system-header-dir=/usr/include \
    --with-newlib \
    --enable-languages=c \
    --without-headers \
    --disable-bootstrap \
    --disable-gcov \
    --disable-multilib \
    --disable-nls \
    --disable-shared \
    --disable-threads \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libssp \
    --disable-libsanitizer \
    --disable-libvtv \
    --disable-decimal-float \
    --disable-werror

make -j"$jobs" all-gcc all-target-libgcc MAKEINFO=true
make install-gcc install-target-libgcc MAKEINFO=true

echo "GCC stage 1 ready under $prefix_dir/bin"
