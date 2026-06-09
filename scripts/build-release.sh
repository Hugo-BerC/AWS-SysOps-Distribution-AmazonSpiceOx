#!/usr/bin/env sh
set -eu

version="${1:?release version required}"
debian_arch="${2:?Debian architecture required}"
profile_id="${3:?profile id required}"
profile_name="${4:?profile name required}"
profiles="${5:?profiles required}"
kernel_image="${6:?kernel image required}"
initramfs_image="${7:?initramfs image required}"
rootfs_image="${8:?rootfs image required}"
rootfs_dir="${9:?rootfs directory required}"
out_dir="${10:?output directory required}"
qemu_append="${11:?QEMU append required}"
qemu_memory="${12:?QEMU memory required}"
qemu_keyboard_layout="${13:-${QEMU_KEYBOARD_LAYOUT:-es}}"
release_flavor="${14:-$profile_id}"

release_name="amazonspiceox-${version}-${debian_arch}-${release_flavor}"
release_parent="$out_dir/release"
release_dir="$release_parent/$release_name"
archive_path="$release_parent/$release_name.tar.gz"

for artifact in "$kernel_image" "$initramfs_image" "$rootfs_image"; do
    if [ ! -f "$artifact" ]; then
        echo "error: missing release artifact: $artifact" >&2
        exit 1
    fi
done

fail_if_file_exists() {
    path="$1"
    if [ -e "$path" ]; then
        echo "error: refusing to package release with local AWS state: $path" >&2
        echo "hint: rebuild the rootfs/image from clean overlays before packaging the release" >&2
        exit 1
    fi
}

image_contains_guest_path() {
    image_path="$1"
    guest_path="$2"
    stat_output="$(debugfs -R "stat $guest_path" "$image_path" 2>&1 || true)"

    printf '%s\n' "$stat_output" | grep -q '^Inode:'
}

if [ -d "$rootfs_dir" ]; then
    fail_if_file_exists "$rootfs_dir/root/.aws/config"
    fail_if_file_exists "$rootfs_dir/root/.aws/credentials"
    fail_if_file_exists "$rootfs_dir/root/.aws/sso"
fi

if command -v debugfs >/dev/null 2>&1 && command -v dumpe2fs >/dev/null 2>&1 && dumpe2fs -h "$rootfs_image" >/dev/null 2>&1; then
    for guest_path in /root/.aws/config /root/.aws/credentials /root/.aws/sso; do
        if image_contains_guest_path "$rootfs_image" "$guest_path"; then
            echo "error: refusing to package release with local AWS state in image: $guest_path" >&2
            echo "hint: run 'sudo -E make image ASOX_PROFILES=\"...\"' from a clean rootfs before release packaging" >&2
            exit 1
        fi
    done
else
    echo "warning: could not inspect rootfs image for AWS state" >&2
fi

rm -rf "$release_dir" "$archive_path" "$archive_path.sha256"
mkdir -p "$release_dir/scripts"

cp "$kernel_image" "$release_dir/bzImage"
cp "$initramfs_image" "$release_dir/rootfs.cpio.gz"
cp "$rootfs_image" "$release_dir/rootfs.ext4"
cp scripts/run-qemu.sh "$release_dir/scripts/run-qemu.sh"
chmod 0755 "$release_dir/scripts/run-qemu.sh"

cat > "$release_dir/run.sh" <<EOF
#!/bin/sh
set -eu

DIR=\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)

QEMU_MEMORY="\${QEMU_MEMORY:-$qemu_memory}" \\
QEMU_APPEND="\${QEMU_APPEND:-$qemu_append}" \\
sh "\$DIR/scripts/run-qemu.sh" "\$DIR/bzImage" "\$DIR/rootfs.cpio.gz" "\$DIR/rootfs.ext4"
EOF

cat > "$release_dir/run-gui.sh" <<EOF
#!/bin/sh
set -eu

DIR=\$(CDPATH= cd -- "\$(dirname -- "\$0")" && pwd)

QEMU_GUI=1 \\
QEMU_MEMORY="\${QEMU_MEMORY:-$qemu_memory}" \\
QEMU_DISPLAY="\${QEMU_DISPLAY:-gtk,gl=off}" \\
QEMU_VGA="\${QEMU_VGA:-std}" \\
QEMU_KEYBOARD_LAYOUT="\${QEMU_KEYBOARD_LAYOUT:-$qemu_keyboard_layout}" \\
QEMU_APPEND="\${QEMU_APPEND:-$qemu_append}" \\
sh "\$DIR/scripts/run-qemu.sh" "\$DIR/bzImage" "\$DIR/rootfs.cpio.gz" "\$DIR/rootfs.ext4"
EOF

chmod 0755 "$release_dir/run.sh" "$release_dir/run-gui.sh"

git_ref="unknown"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_ref="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

cat > "$release_dir/BUILDINFO" <<EOF
name=$release_name
version=$version
architecture=$debian_arch
profile_id=$profile_id
profile_name=$profile_name
profiles=$profiles
release_flavor=$release_flavor
git_ref=$git_ref
kernel_image=bzImage
initramfs=rootfs.cpio.gz
rootfs=rootfs.ext4
qemu_memory=$qemu_memory
qemu_keyboard_layout=$qemu_keyboard_layout
qemu_append=$qemu_append
EOF

cat > "$release_dir/README.md" <<EOF
# AmazonSpiceOx $version

Profile:

\`\`\`text
$profile_name
\`\`\`

## Run

Console mode:

\`\`\`sh
sh run.sh
\`\`\`

Graphical QEMU mode:

\`\`\`sh
sh run-gui.sh
\`\`\`

Inside the guest, the full release profile includes:

- general ops tools
- AWS CLI
- AWS Session Manager plugin
- Terraform
- kubectl and kubeconfig helper
- Chromium / Tkinter GUI runtime
- SSM-PowerConnect launcher

QEMU host gateway aliases inside the guest:

\`\`\`text
host.qemu.internal
host.local
host.docker.internal
host.containers.internal
\`\`\`

AWS SSO browser flows use Chromium through:

\`\`\`text
BROWSER=/usr/local/bin/asox-browser
\`\`\`

Run the desktop tool from arrakis with:

\`\`\`sh
ssm-powerconnect
\`\`\`

The graphical QEMU launcher defaults to Spanish keyboard layout:

\`\`\`sh
QEMU_KEYBOARD_LAYOUT=es sh run-gui.sh
\`\`\`

Override it with another QEMU layout name if your host keyboard differs.

Do not publish images that contain personal AWS config, credentials, or SSO
cache. The release packager checks common AWS paths before creating this
archive.
EOF

(
    cd "$release_dir"
    sha256sum bzImage rootfs.cpio.gz rootfs.ext4 scripts/run-qemu.sh run.sh run-gui.sh BUILDINFO README.md > SHA256SUMS
)

tar -C "$release_parent" -czf "$archive_path" "$release_name"
(
    cd "$release_parent"
    sha256sum "$(basename "$archive_path")" > "$(basename "$archive_path").sha256"
)

echo "Release directory ready: $release_dir"
echo "Release archive ready: $archive_path"
echo "Release checksum ready: $archive_path.sha256"
