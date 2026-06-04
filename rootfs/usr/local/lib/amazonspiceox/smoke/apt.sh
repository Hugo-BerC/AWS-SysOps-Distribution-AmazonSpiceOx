#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/apt.status"
SMOKE_LOG_FILE=/var/log/apt-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_APT_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[apt-smoke] starting apt validation"
sync 2>/dev/null || true

if ! command -v apt-get >/dev/null 2>&1; then
    echo "[apt-smoke] apt-get not found"
    mark_status "AMAZONSPICEOX_APT_SMOKE_NO_APT"
    exit 1
fi

echo "[apt-smoke] /etc/resolv.conf"
cat /etc/resolv.conf || true
echo "[apt-smoke] /etc/nsswitch.conf"
cat /etc/nsswitch.conf || true
echo "[apt-smoke] ip address"
ip addr show 2>/dev/null || true
echo "[apt-smoke] ip route"
ip route show 2>/dev/null || true
echo "[apt-smoke] apt sources"
cat /etc/apt/sources.list || true
sync 2>/dev/null || true

echo "[apt-smoke] getent hosts deb.debian.org"
if ! getent hosts deb.debian.org; then
    echo "[apt-smoke] DNS lookup failed"
    mark_status "AMAZONSPICEOX_APT_SMOKE_DNS_FAILED"
    exit 1
fi

updated=0
for attempt in 1 2 3; do
    echo "[apt-smoke] apt-get update attempt $attempt"
    if apt-get \
        -o APT::Update::Error-Mode=any \
        -o Acquire::Retries=1 \
        -o Acquire::http::Timeout=20 \
        update; then
        updated=1
        mark_status "AMAZONSPICEOX_APT_SMOKE_UPDATED"
        break
    fi
    sync 2>/dev/null || true
    sleep 3
done

if [ "$updated" -ne 1 ]; then
    echo "[apt-smoke] apt-get update failed after retries"
    mark_status "AMAZONSPICEOX_APT_SMOKE_UPDATE_FAILED"
    exit 1
fi

apt-cache policy ca-certificates
sync 2>/dev/null || true

apt-get clean

if ! apt-get \
    -o Acquire::Retries=1 \
    -o Acquire::http::Timeout=20 \
    install \
    --reinstall \
    --download-only \
    -y \
    ca-certificates; then
    mark_status "AMAZONSPICEOX_APT_SMOKE_DOWNLOAD_FAILED"
    exit 1
fi

mark_status "AMAZONSPICEOX_APT_SMOKE_OK"
echo "AMAZONSPICEOX_APT_SMOKE_OK"
