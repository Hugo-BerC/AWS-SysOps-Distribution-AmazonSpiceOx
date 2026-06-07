#!/usr/bin/env sh
set -eu

version="${1:?Terraform version required}"
arch="${2:?Architecture required}"
output_dir="${3:?Output directory required}"

case "$arch" in
    amd64|x86_64)
        platform_arch="amd64"
        ;;
    arm64|aarch64)
        platform_arch="arm64"
        ;;
    *)
        echo "error: unsupported architecture for Terraform: $arch" >&2
        exit 1
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to fetch Terraform" >&2
    exit 1
fi

if ! command -v gpg >/dev/null 2>&1; then
    echo "error: gpg is required to verify Terraform releases" >&2
    echo "hint: install gnupg before using ASOX_PROFILES that include terraform" >&2
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "error: unzip is required to unpack Terraform" >&2
    exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "error: sha256sum is required to verify Terraform checksums" >&2
    exit 1
fi

product="terraform"
archive_name="${product}_${version}_linux_${platform_arch}.zip"
base_url="https://releases.hashicorp.com/${product}/${version}"
zip_path="$output_dir/$archive_name"
shasums_path="$output_dir/terraform_SHA256SUMS"
shasums_sig_path="$output_dir/terraform_SHA256SUMS.sig"
binary_path="$output_dir/terraform"
key_path="$output_dir/hashicorp-security.pgp"
key_url="https://www.hashicorp.com/.well-known/pgp-key.txt"
expected_fingerprint="C874 011F 0AB4 0511 0D02 1055 3436 5D94 72D7 468F"
expected_fingerprint_compact="C874011F0AB405110D02105534365D9472D7468F"

mkdir -p "$output_dir"

echo "Fetching Terraform $version for $arch"
curl --fail --location --output "$zip_path" "$base_url/$archive_name"
curl --fail --location --output "$shasums_path" "$base_url/${product}_${version}_SHA256SUMS"
curl --fail --location --output "$shasums_sig_path" "$base_url/${product}_${version}_SHA256SUMS.sig"
curl --fail --location --output "$key_path" "$key_url"

gnupg_home="$(mktemp -d)"
cleanup() {
    rm -rf "$gnupg_home"
}
trap cleanup EXIT INT TERM
export GNUPGHOME="$gnupg_home"

actual_fingerprint="$(
    gpg --batch --show-keys --with-colons "$key_path" 2>/dev/null | \
        awk -F: '/^fpr:/ { print $10; exit }'
)"

if [ -z "$actual_fingerprint" ]; then
    echo "error: could not extract HashiCorp key fingerprint" >&2
    exit 1
fi

if [ "$actual_fingerprint" != "$expected_fingerprint_compact" ]; then
    echo "error: HashiCorp signing key fingerprint mismatch" >&2
    echo "expected: $expected_fingerprint" >&2
    echo "actual:   $actual_fingerprint" >&2
    gpg --batch --show-keys --fingerprint "$key_path" 2>/dev/null >&2 || true
    exit 1
fi

gpg_import_output="$(gpg --batch --import "$key_path" 2>&1 || true)"
if ! printf '%s\n' "$gpg_import_output" | grep -q 'imported\|not changed'; then
    echo "error: failed to import HashiCorp signing key" >&2
    printf '%s\n' "$gpg_import_output" >&2
    exit 1
fi

gpg_verify_output="$(gpg --batch --verify "$shasums_sig_path" "$shasums_path" 2>&1 || true)"
if ! printf '%s\n' "$gpg_verify_output" | grep -q 'Good signature from'; then
    echo "error: Terraform SHA256SUMS signature verification failed" >&2
    printf '%s\n' "$gpg_verify_output" >&2
    exit 1
fi

(
    cd "$output_dir"
    grep " ${archive_name}\$" "$shasums_path" > terraform_SHA256SUMS.filtered
    sha256sum --check terraform_SHA256SUMS.filtered
)

unzip -p "$zip_path" terraform > "$binary_path"
chmod 0755 "$binary_path"

echo "Terraform $version verified and cached at $binary_path"
