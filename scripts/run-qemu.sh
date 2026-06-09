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
qemu_gui="${QEMU_GUI:-0}"
qemu_display="${QEMU_DISPLAY:-gtk,gl=off}"
qemu_vga="${QEMU_VGA:-std}"
qemu_hostfwd="${QEMU_HOSTFWD:-}"
qemu_keyboard_layout="${QEMU_KEYBOARD_LAYOUT:-es}"

netdev_spec="user,id=net0"

if [ -n "$qemu_hostfwd" ]; then
    old_ifs="$IFS"
    IFS=';'
    for hostfwd_rule in $qemu_hostfwd; do
        [ -n "$hostfwd_rule" ] || continue
        netdev_spec="$netdev_spec,hostfwd=$hostfwd_rule"
    done
    IFS="$old_ifs"
fi

# User-mode networking gives the guest a DHCP server without host setup.
# virtio-net-pci keeps the device simple and fast once the kernel has virtio
# support built in.
set -- \
    -m "$qemu_memory" \
    -kernel "$kernel_image" \
    -initrd "$initramfs_image" \
    -append "$qemu_append" \
    -no-reboot \
    -netdev "$netdev_spec" \
    -device virtio-net-pci,netdev=net0

if [ "$qemu_gui" = "1" ]; then
    set -- "$@" \
        -display "$qemu_display" \
        -vga "$qemu_vga" \
        -usb \
        -device usb-kbd \
        -device usb-tablet

    if [ -n "$qemu_keyboard_layout" ]; then
        set -- "$@" -k "$qemu_keyboard_layout"
    fi
fi

if [ "$qemu_serial_stdio" = "1" ]; then
    if [ "$qemu_gui" = "1" ]; then
        set -- "$@" \
            -monitor none \
            -serial stdio
    else
        set -- "$@" \
            -display none \
            -monitor none \
            -serial stdio
    fi
elif [ -n "$qemu_serial_file" ]; then
    if [ "$qemu_gui" = "1" ]; then
        set -- "$@" \
            -monitor none \
            -serial "file:$qemu_serial_file"
    else
        set -- "$@" \
            -display none \
            -monitor none \
            -serial "file:$qemu_serial_file"
    fi
else
    if [ "$qemu_gui" = "1" ]; then
        set -- "$@" \
            -serial mon:stdio
    else
        set -- "$@" \
            -display none \
            -serial mon:stdio
    fi
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
