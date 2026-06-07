#!/usr/bin/env sh
set -eu

arch="${1:?Debian architecture required}"
output_dir="${2:?Output directory required}"
public_key_file="${3:?Public key file required}"

case "$arch" in
    amd64|x86_64)
        platform="ubuntu_64bit"
        ;;
    arm64|aarch64)
        platform="ubuntu_arm64"
        ;;
    *)
        echo "error: unsupported architecture for Session Manager plugin: $arch" >&2
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to fetch the Session Manager plugin" >&2
    exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
    echo "error: gpg is required to verify the Session Manager plugin signature" >&2
    echo "hint: install gnupg before building ASOX_PROFILES that include ssm" >&2
    exit 1
fi

if [ ! -f "$public_key_file" ]; then
    echo "error: missing Session Manager plugin public key: $public_key_file" >&2
    exit 1
fi

deb_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$platform/session-manager-plugin.deb"
sig_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$platform/session-manager-plugin.deb.sig"
deb_path="$output_dir/session-manager-plugin.deb"
sig_path="$output_dir/session-manager-plugin.deb.sig"
expected_fingerprint="7959 6371 24CE 093A D501 D47A 2C4D 4AFF 6F67 57EE"
expected_fingerprint_compact="7959637124CE093AD501D47A2C4D4AFF6F6757EE"

mkdir -p "$output_dir"

echo "Fetching AWS Session Manager plugin for $arch"
curl --fail --location --output "$deb_path" "$deb_url"
curl --fail --location --output "$sig_path" "$sig_url"

gnupg_home="$(mktemp -d)"
cleanup() {
    rm -rf "$gnupg_home"
}
trap cleanup EXIT INT TERM
export GNUPGHOME="$gnupg_home"

actual_fingerprint="$(
    gpg --batch --show-keys --with-colons "$public_key_file" 2>/dev/null | \
        awk -F: '/^fpr:/ { print $10; exit }'
)"

if [ -z "$actual_fingerprint" ]; then
    echo "error: could not extract a fingerprint from $public_key_file" >&2
    exit 1
fi

fingerprint_output="$(gpg --batch --show-keys --fingerprint "$public_key_file" 2>/dev/null || true)"

if [ "$actual_fingerprint" != "$expected_fingerprint_compact" ]; then
    echo "error: Session Manager plugin signing key fingerprint mismatch" >&2
    echo "expected: $expected_fingerprint" >&2
    echo "actual:   $actual_fingerprint" >&2
    printf '%s\n' "$fingerprint_output" >&2
    exit 1
fi

gpg_import_output="$(gpg --batch --import "$public_key_file" 2>&1 || true)"
if ! printf '%s\n' "$gpg_import_output" | grep -q 'imported\|not changed'; then
    echo "error: failed to import the Session Manager plugin signing key" >&2
    printf '%s\n' "$gpg_import_output" >&2
    exit 1
fi

gpg_verify_output="$(gpg --batch --verify "$sig_path" "$deb_path" 2>&1 || true)"
if ! printf '%s\n' "$gpg_verify_output" | grep -q 'Good signature from'; then
    echo "error: Session Manager plugin signature verification failed" >&2
    printf '%s\n' "$gpg_verify_output" >&2
    exit 1
fi

if command -v dpkg-deb >/dev/null 2>&1; then
    if ! dpkg-deb --info "$deb_path" >/dev/null 2>&1; then
        echo "error: downloaded Session Manager plugin package is not a valid .deb" >&2
        exit 1
    fi
else
    if ! ar t "$deb_path" >/dev/null 2>&1; then
        echo "error: downloaded Session Manager plugin package is not a valid ar archive" >&2
        exit 1
    fi
fi

echo "Session Manager plugin verified and cached at $deb_path"
