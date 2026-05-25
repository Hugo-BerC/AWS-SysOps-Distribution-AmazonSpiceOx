# Changelog

All notable progress in AmazonSpiceOx is tracked here.

## 2026-05-25 - Debian Stable Mirror Pivot

Implemented:

- Debian Stable became the new upstream package base.
- Alpine-specific bootstrap pieces were removed from the primary path.
- `configs/debian/sources.list` was added for pinned Debian repositories.
- `make fetch` now uses `debootstrap --download-only` to cache `.deb`
  packages from a public mirror.
- `make rootfs` now builds the distro rootfs with `debootstrap` plus
  AmazonSpiceOx overlays.
- `scripts/build-rootfs.sh` now writes a Debian-style `apt` sources list into
  the generated image.
- `rootfs/sbin/init` was adjusted to prefer Debian networking tools such as
  `ifup`.
- `initramfs/init` and `rootfs/sbin/init` now fall back cleanly when
  `cttyhack` is not present.
- Manifests were converted to Debian package names.
- Documentation and repo guidance were updated around the Debian workflow.

Notes:

- The package-driven rootfs model is now the default strategy.
- The old BusyBox-compiled rootfs path remains available as `make legacy-rootfs`
  for reference and for the tiny initramfs build.
- The earlier toolchain work remains in the repo as educational material, but
  it is no longer the default distro assembly path.

## Phase I - Minimal Boot

Date: 2026-05

Implemented:

- Vanilla Linux kernel download and build automation.
- BusyBox build automation.
- Minimal initramfs packaging.
- Minimal `/init` as PID 1.
- QEMU boot through `make run`.
- Smoke-testable boot marker.

Result:

```text
AWS SysOps Linux - Milestone 1
AWS_SYSOPS_LINUX_BOOT_OK
asl:/#
```

Notes:

- This was the first successful end-to-end boot.
- The project later evolved in naming and architecture, but this phase proved
  the kernel, BusyBox, initramfs, and QEMU pipeline.

## Phase II - Early Userspace

Date: 2026-05

Implemented:

- Root filesystem template in `rootfs/`.
- Cleaner early userspace init in `initramfs/init`.
- Mounting of `procfs`, `sysfs`, and `devtmpfs`.
- Runtime directories such as `/run`, `/tmp`, `/var/log`, and `/root`.
- Hostname configuration.
- Basic network bring-up with BusyBox tools and DHCP attempt.
- Boot logging and emergency shell handling.
- Dedicated scripts for rootfs, initramfs, and QEMU execution.

Result:

```text
AmazonSpiceOx - Phase II
AMAZONSPICEOX_PHASE2_BOOT_OK
arrakis:/#
```

Notes:

- The distro name became `AmazonSpiceOx`.
- The default hostname became `arrakis`.
- This phase turned the boot shell into a small but coherent early userspace.

## Phase III - Persistent Root Filesystem

Date: 2026-05

Implemented:

- Persistent ext4 root image at `out/rootfs.ext4`.
- QEMU virtio block device attachment.
- Initramfs stage 1 that reads `root=` and runs `switch_root`.
- Stage 2 `/sbin/init` running from the persistent rootfs.
- Basic `/etc/fstab`.
- Persistent root marker in `/var/lib/amazonspiceox/rootfs-state`.
- Reusable root disk behavior so `make run` does not recreate the disk unless
  the image is rebuilt explicitly.

Result:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

Notes:

- This is the first phase where writes can persist across reboots.
- The initramfs is no longer "the whole distro"; it is now the stage-1 boot
  environment that hands off to the real root filesystem.

## Historical Phase IV - Toolchain Bootstrap

Date: 2026-05

Implemented:

- Dedicated toolchain layout under `build/toolchain/`.
- Dedicated sysroot at `build/toolchain/sysroot`.
- Kernel headers export target for the sysroot.
- Cross-binutils bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- GCC stage 1 bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- musl bootstrap target installing libc into the sysroot.
- GCC stage 2 target rebuilding the cross C compiler against musl.
- Static hello-world smoke target built by the cross-toolchain.
- Rootfs injection target so the toolchain hello-world can run inside
  AmazonSpiceOx.
- zlib bootstrap and smoke targets.
- OpenSSL bootstrap and smoke targets.

Notes:

- This work remains useful for learning and experimentation.
- It is no longer the default path for assembling the distro root filesystem.
