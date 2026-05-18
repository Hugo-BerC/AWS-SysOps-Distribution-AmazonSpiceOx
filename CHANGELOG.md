# Changelog

All notable progress in AmazonSpiceOx is tracked here.

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

## Phase IV - Toolchain Bootstrap

Date: 2026-05

Implemented:

- Dedicated toolchain layout under `build/toolchain/`.
- Dedicated sysroot at `build/toolchain/sysroot`.
- Kernel headers export target for the sysroot.
- Cross-binutils bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- GCC stage 1 bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- `gcc-stage1` configured with `--disable-gcov` to avoid unnecessary
  `libgcov` runtime pieces during freestanding bootstrap.
- `gcc-stage1` configured with `--with-newlib` so it can also install the
  minimal target `libgcc` pieces needed by musl for compiler builtins.
- musl bootstrap target installing libc into the sysroot.
- GCC stage 2 target rebuilding the cross C compiler against musl.
- Static hello-world smoke target built by the cross-toolchain.
- Rootfs injection target so the toolchain hello-world can run inside
  AmazonSpiceOx.
- Reproducible build scripts for sysroot and binutils.
- Reproducible build script for GCC stage 1.
- Reproducible build script for musl.
- Reproducible build script for GCC stage 2.

Current result:

```text
make toolchain-sysroot
make binutils
make toolchain
make toolchain-hello
```

Notes:

- This is the start of Phase IV, not the end of it.
- The goal of this slice is to remove the first layer of dependence on the host
  userspace toolchain and establish a controlled target prefix.
- The repo currently tracks musl `1.2.5`, the latest official release on the
  musl site at the time of writing, with the expectation that a later security
  patch or release will replace it for hardened use.
- The next realistic step after this bootstrap is compiling a first nontrivial
  userspace package with the AmazonSpiceOx toolchain.
