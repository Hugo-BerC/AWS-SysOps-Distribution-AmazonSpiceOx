#!/usr/bin/env sh
set -eu

rootfs_dir="${1:?rootfs directory required}"
image="${2:?output ext4 image required}"
size_mb="${3:-256}"
label="${4:-ASOXROOT}"

echo "Building persistent root disk at $image"

mkdir -p "$(dirname "$image")"
rm -f "$image"

# mke2fs can populate an image directly from a directory with -d. That keeps
# the build rootless: no loop mounts and no sudo required.
truncate -s "${size_mb}M" "$image"
mke2fs -q -t ext4 -F -L "$label" -d "$rootfs_dir" "$image"

echo "Root disk ready: $image (${size_mb}M, label=$label)"
