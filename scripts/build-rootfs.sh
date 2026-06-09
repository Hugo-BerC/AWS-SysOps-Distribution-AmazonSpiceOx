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
post_manifests="${DEBIAN_POST_MANIFESTS:-}"
external_deb_packages="${EXTERNAL_DEB_PACKAGES:-}"
external_rootfs_files="${EXTERNAL_ROOTFS_FILES:-}"

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

resolve_package_list() {
    awk 'NF && $1 !~ /^#/' "$@" 2>/dev/null | sort -u | paste -sd, -
}

prepare_chroot_network() {
    root="$1"

    mkdir -p "$root/proc" "$root/sys" "$root/dev"
    mount -t proc proc "$root/proc"
    mount -t sysfs sysfs "$root/sys"
    mount --bind /dev "$root/dev"

    if [ -f "$root/etc/resolv.conf" ]; then
        cp -a "$root/etc/resolv.conf" "$root/etc/resolv.conf.amazonspiceox-pre-post"
    fi

    cp /etc/resolv.conf "$root/etc/resolv.conf"
}

cleanup_chroot_network() {
    root="$1"

    if [ -f "$root/etc/resolv.conf.amazonspiceox-pre-post" ]; then
        mv "$root/etc/resolv.conf.amazonspiceox-pre-post" "$root/etc/resolv.conf"
    fi

    umount "$root/dev" 2>/dev/null || true
    umount "$root/sys" 2>/dev/null || true
    umount "$root/proc" 2>/dev/null || true
}

install_policy_rc_d() {
    root="$1"
    policy_path="$root/usr/sbin/policy-rc.d"
    backup_path="$root/usr/sbin/policy-rc.d.amazonspiceox-pre-post"

    mkdir -p "$root/usr/sbin"

    if [ -e "$policy_path" ] && [ ! -e "$backup_path" ]; then
        mv "$policy_path" "$backup_path"
    fi

    cat > "$policy_path" <<'EOF'
#!/bin/sh
exit 101
EOF
    chmod 0755 "$policy_path"
}

cleanup_policy_rc_d() {
    root="$1"
    policy_path="$root/usr/sbin/policy-rc.d"
    backup_path="$root/usr/sbin/policy-rc.d.amazonspiceox-pre-post"

    if [ -e "$backup_path" ]; then
        mv "$backup_path" "$policy_path"
    else
        rm -f "$policy_path"
    fi
}

install_post_bootstrap_sources() {
    root="$1"
    sources_path="$root/etc/apt/sources.list"
    backup_path="$root/etc/apt/sources.list.amazonspiceox-pre-post"

    mkdir -p "$root/etc/apt"

    if [ -f "$sources_path" ] && [ ! -e "$backup_path" ]; then
        cp -a "$sources_path" "$backup_path"
    fi

    cat > "$sources_path" <<EOF
deb $mirror $suite main
EOF
}

cleanup_post_bootstrap_sources() {
    root="$1"
    sources_path="$root/etc/apt/sources.list"
    backup_path="$root/etc/apt/sources.list.amazonspiceox-pre-post"

    if [ -f "$backup_path" ]; then
        mv "$backup_path" "$sources_path"
    fi
}

install_post_packages() {
    root="$1"
    _source_list="$2"
    manifests="$3"

    set -- $manifests
    [ "$#" -gt 0 ] || return 0

    for post_manifest in "$@"; do
        if [ ! -f "$post_manifest" ]; then
            echo "error: post-bootstrap manifest not found: $post_manifest" >&2
            exit 1
        fi
    done

    post_include_list="$(resolve_package_list "$@")"
    [ -n "$post_include_list" ] || return 0

    echo "Installing post-bootstrap packages into $root: $post_include_list"

    prepare_chroot_network "$root"
    install_policy_rc_d "$root"
    install_post_bootstrap_sources "$root"
    trap 'cleanup_policy_rc_d "$root"; cleanup_post_bootstrap_sources "$root"; cleanup_chroot_network "$root"' EXIT INT TERM

    chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive apt-get update
    chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends $(printf '%s\n' "$post_include_list" | tr ',' ' ')

    cleanup_policy_rc_d "$root"
    cleanup_post_bootstrap_sources "$root"
    cleanup_chroot_network "$root"
    trap - EXIT INT TERM
}

install_external_debs() {
    root="$1"
    deb_packages="$2"

    set -- $deb_packages
    [ "$#" -gt 0 ] || return 0

    external_cache_dir="/var/cache/amazonspiceox/external"
    mkdir -p "$root$external_cache_dir"

    for deb_package in "$@"; do
        if [ ! -f "$deb_package" ]; then
            echo "error: external deb package not found: $deb_package" >&2
            exit 1
        fi
        cp -f "$deb_package" "$root$external_cache_dir/"
    done

    echo "Installing external deb packages into $root"
    prepare_chroot_network "$root"
    install_policy_rc_d "$root"
    install_post_bootstrap_sources "$root"
    trap 'cleanup_policy_rc_d "$root"; cleanup_post_bootstrap_sources "$root"; cleanup_chroot_network "$root"' EXIT INT TERM

    for deb_package in "$@"; do
        deb_basename="$(basename "$deb_package")"
        chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
            dpkg -i "$external_cache_dir/$deb_basename" || \
            chroot "$root" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
                apt-get install -y --no-install-recommends -f
    done

    cleanup_policy_rc_d "$root"
    cleanup_post_bootstrap_sources "$root"
    cleanup_chroot_network "$root"
    trap - EXIT INT TERM
}

install_external_rootfs_files() {
    root="$1"
    file_specs="$2"

    [ -n "$file_specs" ] || return 0

    trim_field() {
        printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }

    old_ifs="$IFS"
    IFS=';'

    for file_spec in $file_specs; do
        file_spec="$(trim_field "$file_spec")"
        [ -n "$file_spec" ] || continue
        IFS=':'
        set -- $file_spec
        IFS=';'

        src_path="$(trim_field "${1:-}")"
        dest_path="$(trim_field "${2:-}")"
        file_mode="$(trim_field "${3:-0755}")"

        if [ -z "$src_path" ] || [ -z "$dest_path" ]; then
            echo "error: malformed EXTERNAL_ROOTFS_FILES entry: $file_spec" >&2
            exit 1
        fi

        if [ ! -f "$src_path" ]; then
            echo "error: external rootfs file not found: $src_path" >&2
            exit 1
        fi

        mkdir -p "$root$(dirname "$dest_path")"
        install -m "$file_mode" "$src_path" "$root$dest_path"
    done

    IFS="$old_ifs"
}

validate_profile_artifacts() {
    root="$1"
    profile="$2"

    case "+$profile+" in
        *+docker+*)
            if [ ! -x "$root/usr/bin/docker" ] && [ ! -x "$root/usr/bin/docker.io" ]; then
                echo "error: docker profile selected, but Docker CLI is missing from rootfs" >&2
                echo "error: expected docker-cli post-bootstrap installation to provide /usr/bin/docker or /usr/bin/docker.io" >&2
                echo "error: post-bootstrap manifests: ${post_manifests:-<none>}" >&2

                if [ -x "$root/usr/bin/dpkg-query" ]; then
                    echo "error: package status for docker runtime packages:" >&2
                    chroot "$root" /usr/bin/dpkg-query -W docker-cli docker.io containerd runc >&2 || true
                fi

                exit 1
            fi
            ;;
    esac
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

include_list="$(resolve_package_list "$@")"

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

install_external_rootfs_files "$rootfs_dir" "$external_rootfs_files"
install_post_packages "$rootfs_dir" "$sources_list" "$post_manifests"
install_external_debs "$rootfs_dir" "$external_deb_packages"

apply_overlays "$overlay_dirs_spec" "$rootfs_dir"

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

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/awscli.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/awscli.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/ssm.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/ssm.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/terraform.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/terraform.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/kubectl.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/kubectl.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/docker.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/docker.sh"
fi

if [ -f "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/ssm-powerconnect.sh" ]; then
    chmod 0755 "$rootfs_dir/usr/local/lib/amazonspiceox/smoke/ssm-powerconnect.sh"
fi

if [ -f "$rootfs_dir/usr/local/bin/terraform" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/terraform"
fi

if [ -f "$rootfs_dir/usr/local/bin/kubectl" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/kubectl"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-kubeconfig" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-kubeconfig"
fi

if [ -f "$rootfs_dir/usr/local/bin/kubeconfig" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/kubeconfig"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-netcheck" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-netcheck"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-console" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-console"
fi

if [ -f "$rootfs_dir/usr/local/bin/docker-start" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/docker-start"
fi

if [ -f "$rootfs_dir/usr/local/bin/docker" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/docker"
fi

if [ -f "$rootfs_dir/usr/local/bin/docker-status" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/docker-status"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-xsession" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-xsession"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-terminal" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-terminal"
fi

if [ -f "$rootfs_dir/usr/local/bin/asox-browser" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/asox-browser"
fi

if [ -f "$rootfs_dir/usr/local/bin/xdg-open" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/xdg-open"
fi

if [ -f "$rootfs_dir/usr/local/bin/x-www-browser" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/x-www-browser"
fi

if [ -f "$rootfs_dir/usr/local/bin/sensible-browser" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/sensible-browser"
fi

if [ -f "$rootfs_dir/usr/local/bin/gui-run" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/gui-run"
fi

if [ -f "$rootfs_dir/usr/local/bin/chrome" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/chrome"
fi

if [ -f "$rootfs_dir/usr/local/bin/python-gui" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/python-gui"
fi

if [ -f "$rootfs_dir/usr/local/bin/xpra-info" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/xpra-info"
fi

if [ -f "$rootfs_dir/usr/local/bin/gui-doctor" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/gui-doctor"
fi

if [ -f "$rootfs_dir/usr/local/bin/ssm-powerconnect" ]; then
    chmod 0755 "$rootfs_dir/usr/local/bin/ssm-powerconnect"
fi

if [ -d "$rootfs_dir/etc/sudoers.d" ]; then
    chmod 0750 "$rootfs_dir/etc/sudoers.d"
    find "$rootfs_dir/etc/sudoers.d" -type f -exec chmod 0440 {} \;
fi

validate_profile_artifacts "$rootfs_dir" "$profile_name"

chmod 0700 "$rootfs_dir/root"
chmod 1777 "$rootfs_dir/tmp"
: > "$rootfs_dir/var/log/boot.log"

echo "Rootfs ready: $rootfs_dir"
