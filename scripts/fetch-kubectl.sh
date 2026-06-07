#!/usr/bin/env sh
set -eu

version="${1:?kubectl version required}"
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
        echo "error: unsupported architecture for kubectl: $arch" >&2
        exit 1
        ;;
esac

case "$version" in
    v*)
        normalized_version="$version"
        ;;
    *)
        normalized_version="v$version"
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to fetch kubectl" >&2
    exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
    echo "error: sha256sum is required to verify kubectl" >&2
    exit 1
fi

binary_url="https://dl.k8s.io/release/${normalized_version}/bin/linux/${platform_arch}/kubectl"
checksum_url="${binary_url}.sha256"
binary_path="$output_dir/kubectl"
checksum_path="$output_dir/kubectl.sha256"

mkdir -p "$output_dir"

echo "Fetching kubectl $normalized_version for $arch"
curl --fail --location --output "$binary_path" "$binary_url"
curl --fail --location --output "$checksum_path" "$checksum_url"

(
    cd "$output_dir"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
)

chmod 0755 "$binary_path"

echo "kubectl $normalized_version verified and cached at $binary_path"
