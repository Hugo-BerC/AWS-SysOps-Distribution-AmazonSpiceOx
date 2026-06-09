#!/bin/sh
set -eu

SMOKE_STATE_DIR=/var/lib/amazonspiceox/smoke
SMOKE_STATUS_FILE="$SMOKE_STATE_DIR/ssm-powerconnect.status"
SMOKE_LOG_FILE=/var/log/ssm-powerconnect-smoke.log

mark_status() {
    printf '%s\n' "$1" > "$SMOKE_STATUS_FILE"
    sync 2>/dev/null || true
}

mkdir -p "$SMOKE_STATE_DIR"
: > "$SMOKE_LOG_FILE"
mark_status "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_STARTED"

exec > "$SMOKE_LOG_FILE" 2>&1

echo "[ssm-powerconnect-smoke] starting SSM-PowerConnect validation"

if [ ! -x /usr/local/bin/ssm-powerconnect ]; then
    echo "[ssm-powerconnect-smoke] launcher missing or not executable"
    mark_status "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_NO_LAUNCHER"
    exit 1
fi

if [ ! -f /opt/ssm-powerconnect/ssm_powerconnect.py ]; then
    echo "[ssm-powerconnect-smoke] app script missing"
    mark_status "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_NO_APP"
    exit 1
fi

if [ ! -f /opt/ssm-powerconnect/skin.jpg ]; then
    echo "[ssm-powerconnect-smoke] skin asset missing"
    mark_status "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_NO_SKIN"
    exit 1
fi

python3 - <<'PY'
import ast
import importlib
from pathlib import Path

app = Path("/opt/ssm-powerconnect/ssm_powerconnect.py")
ast.parse(app.read_text(encoding="utf-8"))

for module_name in (
    "tkinter",
    "boto3",
    "botocore",
    "PIL.Image",
    "PIL.ImageTk",
    "numpy",
    "pandas",
):
    importlib.import_module(module_name)

print("python runtime imports OK")
PY

if command -v sh >/dev/null 2>&1; then
    sh -n /opt/ssm-powerconnect/run.sh
fi

mark_status "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_OK"
echo "AMAZONSPICEOX_SSM_POWERCONNECT_SMOKE_OK"
