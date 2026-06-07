#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/ssm.status"
SMOKE_LOG_FILE=/var/log/ssm-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_SSM_PLUGIN_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[ssm-smoke] starting Session Manager plugin validation"

if ! command -v session-manager-plugin >/dev/null 2>&1; then
    echo "[ssm-smoke] session-manager-plugin command not found"
    mark_status "AMAZONSPICEOX_SSM_PLUGIN_SMOKE_NO_PLUGIN"
    exit 1
fi

echo "[ssm-smoke] session-manager-plugin"
plugin_output="$(session-manager-plugin 2>&1 || true)"
printf '%s\n' "$plugin_output"

if ! printf '%s\n' "$plugin_output" | grep -q 'installed successfully'; then
    echo "[ssm-smoke] plugin self-check did not report success"
    mark_status "AMAZONSPICEOX_SSM_PLUGIN_SMOKE_BAD_SELFTEST"
    exit 1
fi

if command -v aws >/dev/null 2>&1; then
    echo "[ssm-smoke] aws ssm help"
    AWS_PAGER="" aws ssm help >/dev/null
fi

mark_status "AMAZONSPICEOX_SSM_PLUGIN_SMOKE_OK"
echo "AMAZONSPICEOX_SSM_PLUGIN_SMOKE_OK"
