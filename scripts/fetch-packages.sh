#!/usr/bin/env sh
set -eu

suite="${1:?Debian suite required}"
arch="${2:?Debian architecture required}"
mirror="${3:?Debian mirror required}"
cache_dir="${4:?cache directory required}"
shift 4

if [ "$#" -eq 0 ]; then
    echo "error: at least one manifest is required" >&2
    exit 1
fi

if ! command -v debootstrap >/dev/null 2>&1; then
    echo "error: debootstrap is required for Debian package fetching" >&2
    exit 1
fi

include_list="$(
    awk 'NF && $1 !~ /^#/' "$@" | sort -u | paste -sd, -
)"

if [ -z "$include_list" ]; then
    echo "error: no packages found in manifests" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM
target_dir="$tmpdir/rootfs"

mkdir -p "$cache_dir"

echo "Fetching Debian packages into $cache_dir"
debootstrap \
    --arch="$arch" \
    --components=main \
    --variant=minbase \
    --include="$include_list" \
    --cache-dir="$cache_dir" \
    --download-only \
    "$suite" "$target_dir" "$mirror"

echo "Package fetch complete"
