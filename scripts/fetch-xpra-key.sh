#!/usr/bin/env sh
set -eu

output_file="${1:?output key path required}"
expected_fpr="${2:?expected fingerprint required}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

tmp_key="$tmpdir/xpra.asc"
tmp_home="$tmpdir/gnupg"
mkdir -p "$tmp_home"
chmod 700 "$tmp_home"

echo "Fetching Xpra repository signing key"
curl --fail --location --output "$tmp_key" https://xpra.org/xpra.asc

actual_fpr="$(
    gpg --batch --homedir "$tmp_home" --import-options show-only --import --with-colons "$tmp_key" 2>/dev/null \
        | awk -F: '/^fpr:/ { print $10; exit }'
)"

if [ -z "$actual_fpr" ]; then
    echo "error: could not read fingerprint from Xpra signing key" >&2
    exit 1
fi

expected_compact="$(printf '%s' "$expected_fpr" | tr -d '[:space:]')"

if [ "$actual_fpr" != "$expected_compact" ]; then
    echo "error: unexpected Xpra key fingerprint" >&2
    echo "expected: $expected_compact" >&2
    echo "actual:   $actual_fpr" >&2
    exit 1
fi

mkdir -p "$(dirname "$output_file")"
cp "$tmp_key" "$output_file"

echo "Xpra repository key verified: $actual_fpr"
