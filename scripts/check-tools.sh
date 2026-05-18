#!/usr/bin/env sh
set -eu

missing=0

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing: $1"
        missing=1
    fi
}

for tool in curl tar make gcc g++ ld bc bison flex cpio gzip xz bzip2 qemu-system-x86_64 timeout sort yes truncate mke2fs; do
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
        echo "warning: GCC stage 1 prerequisites not found"
        echo "warning: install libgmp-dev libmpfr-dev libmpc-dev before make gcc-stage1"
    fi

    rm -rf "$tmpdir"
    trap - EXIT INT TERM
}

check_gcc_stage1_prereqs

if [ "$missing" -ne 0 ]; then
    echo
    echo "Use the Docker builder for a known-good environment:"
    echo "  docker build -t amazonspiceox-builder ."
    echo "  docker run --rm -it -v \"\${PWD}:/work\" amazonspiceox-builder make run"
    exit 1
fi

echo "All required tools are available."
