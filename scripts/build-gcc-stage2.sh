#!/usr/bin/env sh
set -eu

gcc_src="${1:?gcc source directory required}"
build_dir="${2:?gcc build directory required}"
prefix_dir="${3:?toolchain prefix directory required}"
sysroot_dir="${4:?sysroot directory required}"
target="${5:?target triple required}"
jobs="${6:-1}"

echo "Building GCC stage 2 for $target"

gcc_src="$(cd "$gcc_src" && pwd)"
rm -rf "$build_dir"
mkdir -p "$build_dir" "$prefix_dir"
prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"
export PATH="$prefix_dir/bin:$PATH"

cd "$build_dir"

# Stage 2 rebuilds the cross-compiler against the musl-populated sysroot. We
# still keep the language surface intentionally small: C plus libgcc are enough
# for the next educational steps without dragging in the rest of GCC's runtime
# family.
"$gcc_src/configure" \
    --target="$target" \
    --prefix="$prefix_dir" \
    --with-sysroot="$sysroot_dir" \
    --with-native-system-header-dir=/usr/include \
    --enable-languages=c \
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

echo "GCC stage 2 ready under $prefix_dir/bin"
