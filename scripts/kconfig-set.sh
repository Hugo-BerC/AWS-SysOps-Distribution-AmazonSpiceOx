#!/usr/bin/env sh
set -eu

config_file="${1:?config file required}"
shift

tmp_file="${config_file}.tmp"
cp "$config_file" "$tmp_file"

for assignment in "$@"; do
    name="${assignment%%=*}"
    value="${assignment#*=}"
    symbol="CONFIG_${name}"

    case "$value" in
        y|m)
            line="${symbol}=${value}"
            ;;
        n)
            line="# ${symbol} is not set"
            ;;
        *)
            line="${symbol}=${value}"
            ;;
    esac

    if grep -Eq "^${symbol}=|^# ${symbol} is not set" "$tmp_file"; then
        sed -i -E "s|^${symbol}=.*|${line}|; s|^# ${symbol} is not set|${line}|" "$tmp_file"
    else
        printf '%s\n' "$line" >> "$tmp_file"
    fi
done

mv "$tmp_file" "$config_file"
