#!/usr/bin/env sh
set -eu

prefix_dir="${1:?toolchain prefix directory required}"
sysroot_dir="${2:?sysroot directory required}"
target="${3:?target triple required}"
output="${4:?output binary path required}"

prefix_dir="$(cd "$prefix_dir" && pwd)"
sysroot_dir="$(cd "$sysroot_dir" && pwd)"
output_dir="$(dirname "$output")"
mkdir -p "$output_dir"

cross_cc="$prefix_dir/bin/$target-gcc"
src_file="$output_dir/openssl-smoke.c"

if [ ! -x "$cross_cc" ]; then
    echo "error: cross compiler not found at $cross_cc" >&2
    exit 1
fi

cat > "$src_file" <<'EOF'
#include <stdio.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>

static void print_hex(const unsigned char *buf, unsigned int len)
{
    unsigned int i;

    for (i = 0; i < len; i++) {
        printf("%02x", buf[i]);
    }
}

int main(void)
{
    static const unsigned char input[] = "arrakis";
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_len = 0;
    EVP_MD_CTX *ctx = EVP_MD_CTX_new();

    if (ctx == NULL) {
        fputs("EVP_MD_CTX_new failed\n", stderr);
        return 1;
    }

    if (!EVP_DigestInit_ex(ctx, EVP_sha256(), NULL)
        || !EVP_DigestUpdate(ctx, input, sizeof(input) - 1)
        || !EVP_DigestFinal_ex(ctx, digest, &digest_len)) {
        EVP_MD_CTX_free(ctx);
        fputs("EVP digest flow failed\n", stderr);
        return 1;
    }

    printf("OpenSSL version: %s\n", OpenSSL_version(OPENSSL_VERSION));
    printf("SHA256(arrakis)=");
    print_hex(digest, digest_len);
    putchar('\n');

    EVP_MD_CTX_free(ctx);
    return 0;
}
EOF

echo "Building OpenSSL smoke test at $output"
"$cross_cc" --sysroot="$sysroot_dir" -static -Os -s \
    -I"$sysroot_dir/usr/include" -L"$sysroot_dir/usr/lib" \
    -o "$output" "$src_file" -lcrypto -pthread -ldl

echo "OpenSSL smoke test ready: $output"
