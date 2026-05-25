#!/usr/bin/env sh
set -eu

prefix_dir="${1:?toolchain prefix directory required}"
sysroot_dir="${2:?sysroot directory required}"
target="${3:?target triple required}"
output="${4:?output binary path required}"

prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"
output_dir="$(dirname "$output")"
mkdir -p "$output_dir"

cross_cc="$prefix_dir/bin/$target-gcc"
src_file="$output_dir/zlib-smoke.c"

if [ ! -x "$cross_cc" ]; then
    echo "error: cross compiler not found at $cross_cc" >&2
    exit 1
fi

cat > "$src_file" <<'EOF'
#include <stdio.h>
#include <zlib.h>

int main(void)
{
    printf("zlib version: %s\n", zlibVersion());
    return 0;
}
EOF

echo "Building zlib smoke test at $output"
"$cross_cc" --sysroot="$sysroot_dir" -static -Os -s -I"$sysroot_dir/usr/include" \
    -L"$sysroot_dir/usr/lib" -o "$output" "$src_file" -lz

echo "zlib smoke test ready: $output"
