#!/usr/bin/env sh
set -eu

rootfs_dir="${1:?rootfs directory required}"
image="${2:?output ext4 image required}"
size_mb="${3:-256}"
label="${4:-ASOXROOT}"
headroom_mb="${5:-${ASOX_ROOTFS_HEADROOM_MB:-256}}"

echo "Building persistent root disk at $image"

host_uid="$(id -u)"
host_gid="$(id -g)"
sudo_cmd=""
image_sudo_mode="${ASOX_IMAGE_SUDO:-auto}"
used_kb=""

run_as_root_if_needed() {
    if [ -n "$sudo_cmd" ]; then
        "$sudo_cmd" "$@"
        return
    fi

    "$@"
}

mkdir -p "$(dirname "$image")"
rm -f "$image"

if [ "$host_uid" -ne 0 ] && [ "$image_sudo_mode" != "0" ] && command -v sudo >/dev/null 2>&1; then
    sudo_cmd=sudo
fi

if [ -n "$sudo_cmd" ]; then
    echo "Using sudo for rootfs size scan and image population"
    used_kb="$(sudo du -sk "$rootfs_dir" | awk '{print $1}')"
elif used_kb="$(du -sk "$rootfs_dir" 2>/dev/null | awk '{print $1}')" && [ -n "$used_kb" ]; then
    :
elif [ "$host_uid" -eq 0 ]; then
    echo "error: cannot read rootfs directory size: $rootfs_dir" >&2
    exit 1
else
    echo "error: rootfs contains restricted paths and sudo is not available" >&2
    echo "hint: run 'sudo -E make image ASOX_PROFILES=\"...\"' or install sudo" >&2
    exit 1
fi

used_mb="$(( (used_kb + 1023) / 1024 ))"
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

# mke2fs can populate an image directly from a directory with -d. That avoids
# loop mounts. Debian rootfs trees contain files such as /etc/.pwd.lock and
# private directories that are intentionally unreadable to normal users, so use
# sudo for image population by default when building as an unprivileged user.
truncate -s "${size_mb}M" "$image"
run_as_root_if_needed mke2fs -q -t ext4 -F -L "$label" -d "$rootfs_dir" "$image"

# Hand the resulting artifact back to the invoking user so unprivileged QEMU
# runs can still open it afterwards.
if [ "$host_uid" -eq 0 ] && [ -n "${SUDO_UID:-}" ] && [ -n "${SUDO_GID:-}" ]; then
    chown "${SUDO_UID}:${SUDO_GID}" "$image"
elif [ -n "$sudo_cmd" ]; then
    sudo chown "${host_uid}:${host_gid}" "$image"
fi

chmod 0644 "$image"

echo "Root disk ready: $image (${size_mb}M, label=$label)"
