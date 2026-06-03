#!/usr/bin/env sh
set -eu

src_dir="${1:?source directory required}"
archive="${2:?archive path required}"

topdir="$(tar -tf "$archive" | head -1 | cut -d/ -f1)"
dest_dir="$src_dir/$topdir"

mkdir -p "$src_dir"

if [ -e "$dest_dir" ] && [ ! -w "$dest_dir" ]; then
    echo "error: source tree is not writable: $dest_dir" >&2
    echo "hint: this usually means a previous build was run with sudo" >&2
    echo "hint: fix ownership with: sudo chown -R $(id -un):$(id -gn) build downloads out" >&2
    exit 1
fi

if [ -e "$dest_dir" ]; then
    rm -rf "$dest_dir"
fi

tar -C "$src_dir" -xf "$archive"
