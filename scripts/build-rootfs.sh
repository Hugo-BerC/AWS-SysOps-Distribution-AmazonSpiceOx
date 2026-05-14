#!/usr/bin/env sh
set -eu

busybox_src="${1:?BusyBox source directory required}"
rootfs_template="${2:?rootfs template directory required}"
init_file="${3:?init file required}"
rootfs_dir="${4:?output rootfs directory required}"
busybox_cc="${5:-gcc}"
jobs="${6:-1}"

echo "Building rootfs at $rootfs_dir"

# Recreate the generated root filesystem from scratch. The source of truth is
# rootfs/ plus initramfs/init, so build/rootfs can always be deleted safely.
rm -rf "$rootfs_dir"

mkdir -p "$rootfs_dir"
cp -a "$rootfs_template/." "$rootfs_dir/"
find "$rootfs_dir" -name .gitkeep -delete

mkdir -p \
    "$rootfs_dir/bin" \
    "$rootfs_dir/sbin" \
    "$rootfs_dir/etc" \
    "$rootfs_dir/proc" \
    "$rootfs_dir/sys" \
    "$rootfs_dir/dev" \
    "$rootfs_dir/usr/bin" \
    "$rootfs_dir/usr/sbin" \
    "$rootfs_dir/usr/share/udhcpc" \
    "$rootfs_dir/tmp" \
    "$rootfs_dir/var/log" \
    "$rootfs_dir/root" \
    "$rootfs_dir/run"

make -C "$busybox_src" -j"$jobs" CC="$busybox_cc"
make -C "$busybox_src" CONFIG_PREFIX="$rootfs_dir" install

install -m 0755 "$init_file" "$rootfs_dir/init"

if [ -f "$rootfs_dir/usr/share/udhcpc/default.script" ]; then
    chmod 0755 "$rootfs_dir/usr/share/udhcpc/default.script"
fi

chmod 0700 "$rootfs_dir/root"
chmod 1777 "$rootfs_dir/tmp"
: > "$rootfs_dir/var/log/boot.log"

echo "Rootfs ready: $rootfs_dir"
