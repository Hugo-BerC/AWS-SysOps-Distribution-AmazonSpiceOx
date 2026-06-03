#!/usr/bin/env sh
set -eu

kernel_image="${1:?kernel image required}"
initramfs_image="${2:?initramfs image required}"
rootfs_image="${3:-}"

qemu_bin="${QEMU_BIN:-qemu-system-x86_64}"
qemu_memory="${QEMU_MEMORY:-512M}"
qemu_append="${QEMU_APPEND:-console=ttyS0 panic=-1 init=/init}"
qemu_serial_file="${QEMU_SERIAL_FILE:-}"
qemu_serial_stdio="${QEMU_SERIAL_STDIO:-0}"

# User-mode networking gives the guest a DHCP server without host setup.
# virtio-net-pci keeps the device simple and fast once the kernel has virtio
# support built in.
set -- \
    -m "$qemu_memory" \
    -kernel "$kernel_image" \
    -initrd "$initramfs_image" \
    -append "$qemu_append" \
    -no-reboot \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0

if [ "$qemu_serial_stdio" = "1" ]; then
    set -- "$@" \
        -display none \
        -monitor none \
        -serial stdio
elif [ -n "$qemu_serial_file" ]; then
    set -- "$@" \
        -display none \
        -monitor none \
        -serial "file:$qemu_serial_file"
else
    set -- "$@" \
        -display none \
        -serial mon:stdio
fi

if [ -n "$rootfs_image" ]; then
    set -- "$@" \
        -drive "file=$rootfs_image,if=virtio,format=raw"
fi

if [ "${QEMU_DEBUG:-0}" = "1" ]; then
    # Wait for a debugger on TCP :1234 before the CPU starts executing.
    set -- "$@" -s -S
fi

exec "$qemu_bin" "$@"
