#!/bin/sh
set -u

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/docker.status"
SMOKE_LOG_FILE=/var/log/docker-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

status_name() {
    printf '%s\n' "$1" | tr 'abcdefghijklmnopqrstuvwxyz-' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_'
}

fail_smoke() {
    status="$1"
    shift

    echo "[docker-smoke] $*"
    mark_status "$status"
    exit 1
}

require_command() {
    command_name="$1"
    status_suffix="$(status_name "$command_name")"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "[docker-smoke] $command_name command not found"
        mark_status "AMAZONSPICEOX_DOCKER_SMOKE_NO_${status_suffix}"
        exit 1
    fi
}

run_step() {
    status="$1"
    shift

    echo "[docker-smoke] running: $*"
    "$@" || fail_smoke "$status" "command failed: $*"
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_DOCKER_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[docker-smoke] starting Docker validation"

require_command docker
require_command dockerd
require_command containerd
require_command runc
require_command docker-start
require_command docker-status

run_step "AMAZONSPICEOX_DOCKER_SMOKE_DOCKER_VERSION_FAILED" docker --version

run_step "AMAZONSPICEOX_DOCKER_SMOKE_DOCKERD_VERSION_FAILED" dockerd --version

run_step "AMAZONSPICEOX_DOCKER_SMOKE_CONTAINERD_VERSION_FAILED" containerd --version

run_step "AMAZONSPICEOX_DOCKER_SMOKE_RUNC_VERSION_FAILED" runc --version

echo "[docker-smoke] cgroup mount"
if ! grep -qs " /sys/fs/cgroup " /proc/mounts 2>/dev/null; then
    fail_smoke "AMAZONSPICEOX_DOCKER_SMOKE_NO_CGROUP" "/sys/fs/cgroup is not mounted"
fi

mark_status "AMAZONSPICEOX_DOCKER_SMOKE_OK"
echo "AMAZONSPICEOX_DOCKER_SMOKE_OK"
