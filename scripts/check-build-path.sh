#!/usr/bin/env sh
set -eu

pwd_path="$(pwd)"

case "$pwd_path" in
    /mnt/*)
        cat >&2 <<EOF
error: building AmazonSpiceOx from a mounted Windows path is discouraged:
  $pwd_path

This project builds more reliably from a native Linux filesystem in WSL, for
example:

  ~/aws-sysops-linux

Recommended workflow:

  1. keep the Git-tracked repo on the Windows side
  2. sync it into ~/aws-sysops-linux
  3. build and test from ~/aws-sysops-linux
EOF
        exit 1
        ;;
esac
