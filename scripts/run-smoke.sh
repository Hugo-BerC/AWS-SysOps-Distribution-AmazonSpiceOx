#!/usr/bin/env sh
set -eu

mode="${1:?smoke mode required}"
timeout_value="${2:?timeout value required}"
marker="${3:?marker required}"
log_path="${4:?log path required}"
kernel_image="${5:?kernel image required}"
initramfs_image="${6:?initramfs image required}"
rootfs_image="${7:?rootfs image required}"

show_log_excerpt() {
    log_file="$1"

    if [ ! -e "$log_file" ]; then
        echo "smoke: log file does not exist: $log_file" >&2
        return
    fi

    log_size="$(wc -c < "$log_file" 2>/dev/null || echo 0)"
    echo "smoke: log file: $log_file (${log_size} bytes)" >&2

    if [ "$log_size" = "0" ]; then
        echo "smoke: log file is empty" >&2
        return
    fi

    echo "smoke: first 80 lines" >&2
    sed -n '1,80p' "$log_file" >&2 || true
    echo "smoke: last 80 lines" >&2
    tail -n 80 "$log_file" >&2 || true
}

show_diag_excerpt() {
    diag_file="$1"

    if [ ! -e "$diag_file" ]; then
        return
    fi

    diag_size="$(wc -c < "$diag_file" 2>/dev/null || echo 0)"
    echo "smoke: qemu diagnostic file: $diag_file (${diag_size} bytes)" >&2

    if [ "$diag_size" = "0" ]; then
        return
    fi

    echo "smoke: qemu diagnostics" >&2
    cat "$diag_file" >&2 || true
}

read_guest_file() {
    image_path="$1"
    guest_path="$2"

    debugfs -R "cat $guest_path" "$image_path" 2>/dev/null || true
}

mkdir -p "$(dirname "$log_path")"

actual_log_path="$log_path"
if ! : > "$actual_log_path" 2>/dev/null; then
    actual_log_path="$(mktemp)"
    echo "warning: could not write to $log_path; using temporary log $actual_log_path" >&2
fi

diag_log_path="$(mktemp)"

case "$mode" in
    boot)
        append_args="${QEMU_APPEND:-}"
        ;;
    apt)
        append_args="${QEMU_APPEND:-} asox.smoke=apt"
        ;;
    *)
        echo "error: unknown smoke mode: $mode" >&2
        exit 1
        ;;
esac

echo "smoke: mode=$mode timeout=$timeout_value marker=$marker" >&2
echo "smoke: kernel=$kernel_image initramfs=$initramfs_image rootfs=$rootfs_image" >&2
echo "smoke: requested log path=$log_path" >&2

status=0
QEMU_MEMORY="${QEMU_MEMORY:-512M}" \
QEMU_APPEND="$append_args" \
QEMU_SERIAL_STDIO=1 \
timeout "$timeout_value" \
sh scripts/run-qemu.sh "$kernel_image" "$initramfs_image" "$rootfs_image" \
    > "$actual_log_path" 2> "$diag_log_path" || status=$?

echo "smoke: qemu wrapper exit status=$status" >&2

if [ "$status" != "0" ] && [ "$status" != "124" ]; then
    show_log_excerpt "$actual_log_path"
    show_diag_excerpt "$diag_log_path"
    exit "$status"
fi

marker_found=0

if [ "$mode" = "apt" ]; then
    guest_status="$(read_guest_file "$rootfs_image" /var/lib/amazonspiceox/smoke/apt.status)"

    if printf '%s\n' "$guest_status" | grep -q "$marker"; then
        marker_found=1
    else
        echo "smoke: guest apt status file did not contain marker: $marker" >&2
        echo "smoke: guest apt status content:" >&2
        printf '%s\n' "$guest_status" >&2
        echo "smoke: guest apt log content:" >&2
        read_guest_file "$rootfs_image" /var/log/apt-smoke.log >&2
    fi
else
    if grep -q "$marker" "$actual_log_path"; then
        marker_found=1
    fi
fi

if [ "$marker_found" -ne 1 ]; then
    echo "smoke: marker not found: $marker" >&2
    show_log_excerpt "$actual_log_path"
    show_diag_excerpt "$diag_log_path"
    exit 1
fi

if [ "$actual_log_path" != "$log_path" ]; then
    cp "$actual_log_path" "$log_path" 2>/dev/null || true
fi

echo "Smoke marker found in $actual_log_path"
echo "Requested workspace log path: $log_path"
