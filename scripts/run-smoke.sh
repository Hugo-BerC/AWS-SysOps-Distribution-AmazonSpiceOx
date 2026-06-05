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

debugfs_capture() {
    image_path="$1"
    request="$2"
    stderr_file="$3"

    debugfs -R "$request" "$image_path" 2>"$stderr_file" || return 1
}

read_guest_file() {
    image_path="$1"
    guest_path="$2"
    rel_path="${guest_path#/}"
    stderr_file="$(mktemp)"

    if debugfs_capture "$image_path" "cat $guest_path" "$stderr_file"; then
        rm -f "$stderr_file"
        return 0
    fi

    if debugfs_capture "$image_path" "cat $rel_path" "$stderr_file"; then
        rm -f "$stderr_file"
        return 0
    fi

    echo "smoke: debugfs could not read $guest_path from $image_path" >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stderr_file"
    return 1
}

list_guest_dir() {
    image_path="$1"
    guest_path="$2"
    rel_path="${guest_path#/}"
    stderr_file="$(mktemp)"

    if debugfs_capture "$image_path" "ls -l $guest_path" "$stderr_file"; then
        rm -f "$stderr_file"
        return 0
    fi

    if debugfs_capture "$image_path" "ls -l $rel_path" "$stderr_file"; then
        rm -f "$stderr_file"
        return 0
    fi

    echo "smoke: debugfs could not list $guest_path from $image_path" >&2
    cat "$stderr_file" >&2 || true
    rm -f "$stderr_file"
    return 1
}

repair_guest_fs() {
    image_path="$1"

    if ! command -v e2fsck >/dev/null 2>&1; then
        return 0
    fi

    echo "smoke: running e2fsck on $image_path before guest file inspection" >&2
    e2fsck -fy "$image_path" >/dev/null 2>&1 || true
}

show_guest_smoke_failure() {
    image_path="$1"
    status_path="$2"
    log_file_path="$3"
    marker_text="$4"
    label="$5"
    status_value="$6"

    echo "smoke: guest $label status file did not contain marker: $marker_text" >&2
    echo "smoke: guest $label status content:" >&2
    printf '%s\n' "$status_value" >&2
    echo "smoke: guest /var/lib/amazonspiceox directory:" >&2
    list_guest_dir "$image_path" /var/lib/amazonspiceox >&2 || true
    echo "smoke: guest /var/lib/amazonspiceox/smoke directory:" >&2
    list_guest_dir "$image_path" /var/lib/amazonspiceox/smoke >&2 || true
    echo "smoke: guest persistent root marker:" >&2
    read_guest_file "$image_path" /var/lib/amazonspiceox/rootfs-state >&2 || true
    echo "smoke: guest /var/log directory:" >&2
    list_guest_dir "$image_path" /var/log >&2 || true
    echo "smoke: guest boot log content:" >&2
    read_guest_file "$image_path" /var/log/boot.log >&2 || true
    echo "smoke: guest $label log content:" >&2
    read_guest_file "$image_path" "$log_file_path" >&2 || true
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
        append_args="${QEMU_APPEND:-console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw}"
        ;;
    awscli)
        append_args="${QEMU_APPEND:-console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw} asox.smoke=awscli"
        ;;
    net|network)
        append_args="${QEMU_APPEND:-console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw} asox.smoke=network"
        ;;
    apt)
        append_args="${QEMU_APPEND:-console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw} asox.smoke=apt"
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
QEMU_SERIAL_FILE="$actual_log_path" \
timeout --signal=INT --kill-after=5s "$timeout_value" \
sh scripts/run-qemu.sh "$kernel_image" "$initramfs_image" "$rootfs_image" \
    > /dev/null 2> "$diag_log_path" || status=$?

echo "smoke: qemu wrapper exit status=$status" >&2

if [ "$status" != "0" ] && [ "$status" != "124" ]; then
    show_log_excerpt "$actual_log_path"
    show_diag_excerpt "$diag_log_path"
    exit "$status"
fi

marker_found=0

if [ "$mode" = "apt" ] || [ "$mode" = "net" ] || [ "$mode" = "network" ] || [ "$mode" = "awscli" ]; then
    repair_guest_fs "$rootfs_image"

    if [ "$mode" = "apt" ]; then
        guest_status_path="/var/lib/amazonspiceox/smoke/apt.status"
        guest_log_path="/var/log/apt-smoke.log"
        guest_label="apt"
    elif [ "$mode" = "awscli" ]; then
        guest_status_path="/var/lib/amazonspiceox/smoke/awscli.status"
        guest_log_path="/var/log/awscli-smoke.log"
        guest_label="awscli"
    else
        guest_status_path="/var/lib/amazonspiceox/smoke/network.status"
        guest_log_path="/var/log/network-smoke.log"
        guest_label="network"
    fi

    guest_status="$(read_guest_file "$rootfs_image" "$guest_status_path" || true)"

    if printf '%s\n' "$guest_status" | grep -q "$marker"; then
        marker_found=1
    else
        show_guest_smoke_failure "$rootfs_image" "$guest_status_path" "$guest_log_path" "$marker" "$guest_label" "$guest_status"
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
