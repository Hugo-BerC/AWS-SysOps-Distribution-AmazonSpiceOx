#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/apt.status"
SMOKE_LOG_FILE=/var/log/apt-smoke.log

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
rm -f "$SMOKE_STATUS_FILE"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[apt-smoke] starting apt validation"

if ! command -v apt-get >/dev/null 2>&1; then
    echo "[apt-smoke] apt-get not found"
    exit 1
fi

echo "[apt-smoke] /etc/resolv.conf"
cat /etc/resolv.conf || true
echo "[apt-smoke] ip address"
ip addr show 2>/dev/null || true
echo "[apt-smoke] ip route"
ip route show 2>/dev/null || true
echo "[apt-smoke] apt sources"
cat /etc/apt/sources.list || true

updated=0
for attempt in 1 2 3; do
    echo "[apt-smoke] apt-get update attempt $attempt"
    if apt-get \
        -o Acquire::Retries=1 \
        -o Acquire::http::Timeout=20 \
        update; then
        updated=1
        break
    fi
    sleep 3
done

if [ "$updated" -ne 1 ]; then
    echo "[apt-smoke] apt-get update failed after retries"
    exit 1
fi

apt-cache policy ca-certificates

apt-get \
    -o Acquire::Retries=1 \
    -o Acquire::http::Timeout=20 \
    install \
    --reinstall \
    --download-only \
    -y \
    ca-certificates

printf '%s\n' "AMAZONSPICEOX_APT_SMOKE_OK" > "$SMOKE_STATUS_FILE"
sync 2>/dev/null || true
echo "AMAZONSPICEOX_APT_SMOKE_OK"
