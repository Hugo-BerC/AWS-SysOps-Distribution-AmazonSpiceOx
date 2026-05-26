#!/usr/bin/env sh
set -eu

rootfs_dir="${1:?rootfs directory required}"
image="${2:?output ext4 image required}"
size_mb="${3:-256}"
label="${4:-ASOXROOT}"

echo "Building persistent root disk at $image"

mkdir -p "$(dirname "$image")"
rm -f "$image"

used_kb="$(du -sk "$rootfs_dir" | awk '{print $1}')"
used_mb="$(( (used_kb + 1023) / 1024 ))"
headroom_mb=256
minimum_mb=512
required_mb="$(( used_mb + headroom_mb ))"

if [ "$required_mb" -lt "$minimum_mb" ]; then
    required_mb="$minimum_mb"
fi

rounded_mb="$(( ((required_mb + 63) / 64) * 64 ))"

if [ "$size_mb" -lt "$rounded_mb" ]; then
    echo "Requested size ${size_mb}M is too small for this rootfs (${used_mb}M used); growing image to ${rounded_mb}M"
    size_mb="$rounded_mb"
fi

# mke2fs can populate an image directly from a directory with -d. That keeps
# the build rootless: no loop mounts and no sudo required.
truncate -s "${size_mb}M" "$image"
mke2fs -q -t ext4 -F -L "$label" -d "$rootfs_dir" "$image"

echo "Root disk ready: $image (${size_mb}M, label=$label)"
