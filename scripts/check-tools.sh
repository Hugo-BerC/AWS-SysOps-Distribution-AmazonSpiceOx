#!/usr/bin/env sh
set -eu

missing=0

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing: $1"
        missing=1
    fi
}

for tool in awk ar curl make gcc g++ ld bc bison flex cpio gzip mktemp tar timeout sort xargs xz bzip2 qemu-system-x86_64 yes truncate mke2fs debootstrap; do
    need "$tool"
done

if ! command -v musl-gcc >/dev/null 2>&1; then
    echo "warning: musl-gcc not found; BusyBox will use gcc unless BUSYBOX_CC is set"
fi

check_gcc_stage1_prereqs() {
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT INT TERM

    cat > "$tmpdir/test.cc" <<'EOF'
#include <gmp.h>
#include <mpfr.h>
#include <mpc.h>
int main() { return 0; }
EOF

    if ! g++ "$tmpdir/test.cc" -lgmp -lmpfr -lmpc -o "$tmpdir/test" >/dev/null 2>&1; then
        echo "warning: optional legacy toolchain prerequisites not found"
        echo "warning: install libgmp-dev libmpfr-dev libmpc-dev before make gcc-stage1"
    fi

    rm -rf "$tmpdir"
    trap - EXIT INT TERM
}

check_gcc_stage1_prereqs

check_openssl_prereqs() {
    if ! command -v perl >/dev/null 2>&1; then
        echo "warning: optional legacy toolchain prerequisite not found: perl"
        echo "warning: install perl before make openssl"
        return
    fi

    if ! perl -MText::Template -e 1 >/dev/null 2>&1; then
        echo "warning: optional legacy toolchain prerequisite not found: Perl module Text::Template"
        echo "warning: install libtext-template-perl before make openssl"
    fi
}

check_openssl_prereqs

if [ "$missing" -ne 0 ]; then
    echo
    echo "Suggested Debian/Ubuntu host packages:"
    echo "  sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev cpio curl xz-utils bzip2 gzip make qemu-system-x86 debootstrap binutils file ca-certificates e2fsprogs"
    exit 1
fi

echo "note: Debian rootfs assembly requires sudo for 'make rootfs' and usually for 'make image' as well"

echo "All required tools are available."
