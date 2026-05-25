#!/usr/bin/env sh
set -eu

cache_dir="${1:?package cache directory required}"

if [ ! -d "$cache_dir" ]; then
    echo "error: package cache directory not found: $cache_dir" >&2
    exit 1
fi

found=0
for pkg in "$cache_dir"/*.deb; do
    if [ ! -f "$pkg" ]; then
        continue
    fi

    found=1
    ar t "$pkg" >/dev/null 2>&1 || {
        echo "error: invalid deb archive: $pkg" >&2
        exit 1
    }
done

if [ "$found" -eq 0 ]; then
    echo "error: no deb packages found in $cache_dir" >&2
    exit 1
fi

echo "All cached deb archives look valid."
