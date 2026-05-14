#!/usr/bin/env sh
set -eu

kernel_image="${1:?kernel image required}"
initramfs_image="${2:?initramfs image required}"

qemu_bin="${QEMU_BIN:-qemu-system-x86_64}"
qemu_memory="${QEMU_MEMORY:-512M}"
qemu_append="${QEMU_APPEND:-console=ttyS0 panic=-1 init=/init}"

# User-mode networking gives the guest a DHCP server without host setup.
# virtio-net-pci keeps the device simple and fast once the kernel has virtio
# support built in.
set -- \
    -m "$qemu_memory" \
    -kernel "$kernel_image" \
    -initrd "$initramfs_image" \
    -append "$qemu_append" \
    -display none \
    -serial mon:stdio \
    -no-reboot \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0

if [ "${QEMU_DEBUG:-0}" = "1" ]; then
    # Wait for a debugger on TCP :1234 before the CPU starts executing.
    set -- "$@" -s -S
fi

exec "$qemu_bin" "$@"
