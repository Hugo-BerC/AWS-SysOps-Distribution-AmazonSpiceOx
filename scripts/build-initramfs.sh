#!/usr/bin/env sh
set -eu

rootfs_dir="${1:?rootfs directory required}"
output="${2:?output cpio.gz required}"

echo "Packing initramfs from $rootfs_dir"
mkdir -p "$(dirname "$output")"

# The kernel expects the initramfs archive in the old/new ASCII cpio format.
# newc is the common choice for Linux initramfs images.
(
    cd "$rootfs_dir"
    find . -print0 | sort -z | cpio --null --create --quiet --format=newc
) | gzip -9 > "$output"

echo "Initramfs ready: $output"
