#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/awscli.status"
SMOKE_LOG_FILE=/var/log/awscli-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_AWSCLI_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[awscli-smoke] starting awscli validation"

export AWS_CONFIG_FILE=/tmp/amazonspiceox-awscli-smoke-config
export AWS_SHARED_CREDENTIALS_FILE=/tmp/amazonspiceox-awscli-smoke-credentials
export AWS_EC2_METADATA_DISABLED=true
export AWS_PAGER=""

: > "$AWS_CONFIG_FILE"
: > "$AWS_SHARED_CREDENTIALS_FILE"
chmod 0600 "$AWS_CONFIG_FILE" "$AWS_SHARED_CREDENTIALS_FILE" 2>/dev/null || true

if [ -e /root/.aws/config ] || [ -e /root/.aws/credentials ]; then
    echo "[awscli-smoke] ignoring local /root/.aws state for smoke validation"
fi

if ! command -v aws >/dev/null 2>&1; then
    echo "[awscli-smoke] aws command not found"
    mark_status "AMAZONSPICEOX_AWSCLI_SMOKE_NO_AWS"
    exit 1
fi

echo "[awscli-smoke] aws --version"
aws --version

echo "[awscli-smoke] aws help"
aws help >/dev/null

echo "[awscli-smoke] aws configure list"
aws configure list || true

mark_status "AMAZONSPICEOX_AWSCLI_SMOKE_OK"
echo "AMAZONSPICEOX_AWSCLI_SMOKE_OK"
