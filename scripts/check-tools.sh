#!/usr/bin/env sh
set -eu

missing=0

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "missing: $1"
        missing=1
    fi
}

for tool in curl tar make gcc ld bc bison flex cpio gzip xz bzip2 qemu-system-x86_64 timeout sort yes truncate mke2fs; do
    need "$tool"
done

if ! command -v musl-gcc >/dev/null 2>&1; then
    echo "warning: musl-gcc not found; BusyBox will use gcc unless BUSYBOX_CC is set"
fi

if [ "$missing" -ne 0 ]; then
    echo
    echo "Use the Docker builder for a known-good environment:"
    echo "  docker build -t amazonspiceox-builder ."
    echo "  docker run --rm -it -v \"\${PWD}:/work\" amazonspiceox-builder make run"
    exit 1
fi

echo "All required tools are available."
