if [ "$(id -u 2>/dev/null || echo 1)" = "0" ] \
    && [ "${ASOX_DNS_AUTO_FIX:-1}" = "1" ] \
    && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null \
    && command -v asox-dns-fix >/dev/null 2>&1 \
    && ! grep -q '^nameserver[[:space:]]8\.8\.8\.8' /etc/resolv.conf 2>/dev/null; then
    ASOX_DNS_FIX_QUIET=1 asox-dns-fix wsl >/dev/null 2>&1 || true
fi
