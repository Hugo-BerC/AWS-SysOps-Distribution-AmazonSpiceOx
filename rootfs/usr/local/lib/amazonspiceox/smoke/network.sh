#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/network.status"
SMOKE_LOG_FILE=/var/log/network-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_NETWORK_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[network-smoke] starting network validation"

if ! command -v ip >/dev/null 2>&1; then
    echo "[network-smoke] ip command not found"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_NO_IP_TOOL"
    exit 1
fi

echo "[network-smoke] ip address"
ip addr show 2>/dev/null || true
echo "[network-smoke] ip route"
ip route show 2>/dev/null || true
echo "[network-smoke] resolv.conf"
cat /etc/resolv.conf 2>/dev/null || true
echo "[network-smoke] nsswitch.conf"
cat /etc/nsswitch.conf 2>/dev/null || true

if ! ip -4 addr show dev eth0 2>/dev/null | grep -q 'inet '; then
    echo "[network-smoke] eth0 has no IPv4 address"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_NO_IPV4"
    exit 1
fi

if ! ip route show default 2>/dev/null | grep -q '^default '; then
    echo "[network-smoke] no default route"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_NO_DEFAULT_ROUTE"
    exit 1
fi

if ! ping -c 1 10.0.2.2; then
    echo "[network-smoke] could not reach QEMU gateway 10.0.2.2"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_GATEWAY_FAILED"
    exit 1
fi

if ! getent hosts host.qemu.internal; then
    echo "[network-smoke] host.qemu.internal alias is missing"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_HOST_ALIAS_FAILED"
    exit 1
fi

if ! getent hosts deb.debian.org; then
    echo "[network-smoke] DNS lookup failed for deb.debian.org"
    mark_status "AMAZONSPICEOX_NETWORK_SMOKE_DNS_FAILED"
    exit 1
fi

mark_status "AMAZONSPICEOX_NETWORK_SMOKE_OK"
echo "AMAZONSPICEOX_NETWORK_SMOKE_OK"
