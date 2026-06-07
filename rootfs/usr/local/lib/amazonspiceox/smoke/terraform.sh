#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/terraform.status"
SMOKE_LOG_FILE=/var/log/terraform-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_TERRAFORM_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[terraform-smoke] starting terraform validation"

if ! command -v terraform >/dev/null 2>&1; then
    echo "[terraform-smoke] terraform command not found"
    mark_status "AMAZONSPICEOX_TERRAFORM_SMOKE_NO_TERRAFORM"
    exit 1
fi

echo "[terraform-smoke] terraform version"
terraform version

echo "[terraform-smoke] terraform -help"
terraform -help >/dev/null

mark_status "AMAZONSPICEOX_TERRAFORM_SMOKE_OK"
echo "AMAZONSPICEOX_TERRAFORM_SMOKE_OK"
