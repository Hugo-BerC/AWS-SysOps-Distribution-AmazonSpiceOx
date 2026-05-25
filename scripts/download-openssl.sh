#!/usr/bin/env sh
set -eu

output="${1:?output path required}"
shift

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM
tmpfile="$tmpdir/openssl.tar.gz"

for url in "$@"; do
    echo "Trying OpenSSL source: $url"

    rm -f "$tmpfile"

    if ! curl --fail --location --output "$tmpfile" "$url"; then
        echo "warning: download failed from $url" >&2
        continue
    fi

    if ! tar -tzf "$tmpfile" >/dev/null 2>&1; then
        echo "warning: downloaded file from $url is not a valid tar.gz archive" >&2
        continue
    fi

    mv "$tmpfile" "$output"
    echo "OpenSSL source downloaded to $output"
    exit 0
done

echo "error: could not download a valid OpenSSL archive from any configured source" >&2
exit 1
