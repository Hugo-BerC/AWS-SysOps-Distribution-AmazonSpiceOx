#!/usr/bin/env sh
set -eu

output="${1:?output sources.list path required}"
mirror="${2:-https://deb.debian.org/debian}"
suite="${3:-trixie}"
components="${4:-main}"
security_mirror="${5:-https://security.debian.org/debian-security}"

mkdir -p "$(dirname "$output")"

cat > "$output" <<EOF
deb $mirror $suite $components
deb $mirror ${suite}-updates $components
deb $security_mirror ${suite}-security $components
EOF

echo "Sources list updated at $output"
