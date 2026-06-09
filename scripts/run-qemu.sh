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
qemu_accel="${QEMU_ACCEL:-auto}"
qemu_cpu="${QEMU_CPU:-auto}"
qemu_smp="${QEMU_SMP:-2}"
qemu_clipboard="${QEMU_CLIPBOARD:-auto}"
qemu_host_ip="${QEMU_HOST_IP:-auto}"

netdev_spec="user,id=net0"

detect_accel() {
    host_os="$(uname -s 2>/dev/null || echo unknown)"
    host_arch="$(uname -m 2>/dev/null || echo unknown)"

    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        printf '%s\n' kvm
        return 0
    fi

    if [ -e /dev/kvm ]; then
        echo "warning: /dev/kvm exists but is not writable by this user; falling back to TCG" >&2
        echo "warning: add the user to the kvm group and restart WSL/Linux for fast QEMU" >&2
    fi

    if [ "$host_os" = "Darwin" ] && [ "$host_arch" = "x86_64" ]; then
        printf '%s\n' hvf
        return 0
    fi

    printf '%s\n' tcg
}

detect_host_ip() {
    if [ -n "${WSL_INTEROP:-}" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        awk '/^nameserver[[:space:]]/ { print $2; exit }' /etc/resolv.conf 2>/dev/null || true
        return 0
    fi

    printf '%s\n' ""
}

supports_qemu_vdagent() {
    "$qemu_bin" -chardev help 2>&1 | grep -q 'qemu-vdagent'
}

if [ -n "$qemu_hostfwd" ]; then
    old_ifs="$IFS"
    IFS=';'
    for hostfwd_rule in $qemu_hostfwd; do
        [ -n "$hostfwd_rule" ] || continue
        netdev_spec="$netdev_spec,hostfwd=$hostfwd_rule"
    done
    IFS="$old_ifs"
fi

if [ "$qemu_host_ip" = "auto" ]; then
    qemu_host_ip="$(detect_host_ip)"
fi

if [ -n "$qemu_host_ip" ]; then
    qemu_append="$qemu_append asox.host_ip=$qemu_host_ip"
fi

if [ "$qemu_accel" = "auto" ]; then
    qemu_accel="$(detect_accel)"
fi

# User-mode networking gives the guest a DHCP server without host setup.
# virtio-net-pci keeps the device simple and fast once the kernel has virtio
# support built in.
set -- \
    -m "$qemu_memory" \
    -smp "$qemu_smp" \
    -kernel "$kernel_image" \
    -initrd "$initramfs_image" \
    -append "$qemu_append" \
    -no-reboot \
    -netdev "$netdev_spec" \
    -device virtio-net-pci,netdev=net0

case "$qemu_accel" in
    ""|none|off)
        ;;
    tcg)
        set -- "$@" -accel tcg,thread=multi
        ;;
    *)
        set -- "$@" -accel "$qemu_accel"
        if [ "$qemu_cpu" = "auto" ] && [ "$qemu_accel" = "kvm" ]; then
            qemu_cpu=host
        fi
        ;;
esac

if [ "$qemu_cpu" != "auto" ] && [ -n "$qemu_cpu" ]; then
    set -- "$@" -cpu "$qemu_cpu"
fi

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

    if [ "$qemu_clipboard" = "auto" ]; then
        if supports_qemu_vdagent; then
            qemu_clipboard=1
        else
            qemu_clipboard=0
        fi
    fi

    case "$qemu_clipboard" in
        1|yes|true|on)
            set -- "$@" \
                -device virtio-serial-pci \
                -chardev qemu-vdagent,id=spiceagent,name=vdagent,clipboard=on \
                -device virtserialport,chardev=spiceagent,name=com.redhat.spice.0
            ;;
    esac
fi

if [ "$qemu_serial_stdio" = "1" ]; then
    if [ "$qemu_gui" = "1" ]; then
        set -- "$@" \
            -monitor none \
            -chardev stdio,id=serial0,signal=off \
            -serial chardev:serial0
    else
        set -- "$@" \
            -display none \
            -monitor none \
            -chardev stdio,id=serial0,signal=off \
            -serial chardev:serial0
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
            -monitor none \
            -chardev stdio,id=serial0,signal=off \
            -serial chardev:serial0
    else
        set -- "$@" \
            -display none \
            -monitor none \
            -chardev stdio,id=serial0,signal=off \
            -serial chardev:serial0
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
