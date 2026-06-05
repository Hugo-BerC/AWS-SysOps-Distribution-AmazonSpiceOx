#!/usr/bin/env sh
set -eu

suite="${1:?Debian suite required}"
arch="${2:?Debian architecture required}"
mirror="${3:?Debian mirror required}"
sources_list="${4:?sources.list template required}"
overlay_dirs_spec="${5:?overlay directories required}"
init_file="${6:?init file required}"
rootfs_dir="${7:?output rootfs directory required}"
cache_dir="${8:?cache directory required}"
profile_name="${9:?profile name required}"
shift 9

apply_overlay() {
    src_root="$1"
    dst_root="$2"

    find "$src_root" -mindepth 1 | while IFS= read -r src_path; do
        rel_path="${src_path#$src_root/}"
        dest_path="$dst_root/$rel_path"

        case "$rel_path" in
            *.gitkeep)
                continue
                ;;
        esac

        if [ -d "$src_path" ] && [ ! -L "$src_path" ]; then
            if [ -e "$dest_path" ] && [ ! -d "$dest_path" ]; then
                continue
            fi

            mkdir -p "$dest_path"
            continue
        fi

        mkdir -p "$(dirname "$dest_path")"
        cp -a "$src_path" "$dest_path"
    done
}

apply_overlays() {
    overlay_dirs="$1"
    dst_root="$2"
    old_ifs="$IFS"
    IFS=":"

    for overlay_dir in $overlay_dirs; do
        [ -d "$overlay_dir" ] || continue
        apply_overlay "$overlay_dir" "$dst_root"
    done

    IFS="$old_ifs"
}

if [ "$#" -eq 0 ]; then
    echo "error: at least one manifest is required" >&2
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "error: debootstrap is required for the Debian mirror workflow" >&2
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "error: Debian rootfs assembly currently requires root privileges" >&2
    echo "hint: run 'sudo -E make rootfs' or 'sudo -E make all'" >&2
    exit 1
fi

include_list="$(
    awk 'NF && $1 !~ /^#/' "$@" | sort -u | paste -sd, -
)"

if [ -z "$include_list" ]; then
    echo "error: no packages found in manifests" >&2
    exit 1
fi

echo "Building Debian-based rootfs at $rootfs_dir"
rm -rf "$rootfs_dir"
mkdir -p "$rootfs_dir" "$cache_dir"

if ! debootstrap \
    --arch="$arch" \
    --components=main \
    --variant=minbase \
    --include="$include_list" \
    --cache-dir="$cache_dir" \
    "$suite" "$rootfs_dir" "$mirror"; then
    echo "error: debootstrap failed for profile $profile_name" >&2
    if [ -f "$rootfs_dir/debootstrap/debootstrap.log" ]; then
        echo "error: tail of $rootfs_dir/debootstrap/debootstrap.log" >&2
        tail -n 120 "$rootfs_dir/debootstrap/debootstrap.log" >&2 || true
    fi
    exit 1
fi

apply_overlays "$overlay_dirs_spec" "$rootfs_dir"

mkdir -p \
    "$rootfs_dir/etc/profile.d" \
    "$rootfs_dir/proc" \
    "$rootfs_dir/sys" \
    "$rootfs_dir/dev" \
    "$rootfs_dir/run" \
    "$rootfs_dir/tmp" \
    "$rootfs_dir/var/log" \
    "$rootfs_dir/root" \
    "$rootfs_dir/var/lib/amazonspiceox"

mkdir -p "$rootfs_dir/etc/apt"
cp "$sources_list" "$rootfs_dir/etc/apt/sources.list"
printf '%s\n' "$profile_name" > "$rootfs_dir/etc/amazonspiceox-profile"

install -m 0755 "$init_file" "$rootfs_dir/init"

if [ -f "$rootfs_dir/sbin/init" ]; then
    chmod 0755 "$rootfs_dir/sbin/init"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/apt.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/apt.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/network.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/network.sh"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-netcheck" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-netcheck"
fi

chmod 0700 "$rootfs_dir/root"
chmod 1777 "$rootfs_dir/tmp"
: > "$rootfs_dir/var/log/boot.log"

echo "Rootfs ready: $rootfs_dir"
