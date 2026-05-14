#!/usr/bin/env sh
set -eu

# Backward-compatible wrapper kept for Milestone 1 notes.
exec sh scripts/build-initramfs.sh "$@"
