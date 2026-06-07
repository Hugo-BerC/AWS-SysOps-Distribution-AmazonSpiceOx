#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/kubectl.status"
SMOKE_LOG_FILE=/var/log/kubectl-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_KUBECTL_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[kubectl-smoke] starting kubectl validation"

if ! command -v kubectl >/dev/null 2>&1; then
    echo "[kubectl-smoke] kubectl command not found"
    mark_status "AMAZONSPICEOX_KUBECTL_SMOKE_NO_KUBECTL"
    exit 1
fi

if ! command -v kubeconfig >/dev/null 2>&1; then
    echo "[kubectl-smoke] kubeconfig command not found"
    mark_status "AMAZONSPICEOX_KUBECTL_SMOKE_NO_KUBECONFIG_HELPER"
    exit 1
fi

echo "[kubectl-smoke] initializing kubeconfig"
kubeconfig init >/dev/null

echo "[kubectl-smoke] kubectl version --client"
kubectl version --client=true --output=yaml

echo "[kubectl-smoke] kubectl config view"
kubectl config view >/dev/null

echo "[kubectl-smoke] kubeconfig status"
kubeconfig status

mark_status "AMAZONSPICEOX_KUBECTL_SMOKE_OK"
echo "AMAZONSPICEOX_KUBECTL_SMOKE_OK"
