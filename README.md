# Mentat Linux

Mentat Linux is an educational Linux distribution built from small, explicit
pieces: vanilla Linux, BusyBox, initramfs, early userspace, and QEMU.

The long-term direction is an AWS SysOps-oriented distro, but the immediate
goal is learning Linux internals deeply and reproducibly.

## Current Status

Phase II: real root filesystem structure and early userspace.

The system now boots in QEMU, mounts the core virtual filesystems, configures a
hostname, brings up basic networking, writes a boot log, and launches an
interactive BusyBox shell.

Expected marker:

```text
Mentat Linux - Phase II
MENTAT_LINUX_PHASE2_BOOT_OK
mentat:/#
```

## Build

On WSL or Linux:

```sh
make deps
make all
make run
```

Useful targets:

```sh
make rootfs     # build build/rootfs from rootfs/ + BusyBox + initramfs/init
make initramfs  # package build/rootfs as out/rootfs.cpio.gz
make run        # boot QEMU
make smoke      # boot briefly and check the Phase II marker
make clean
```

## Output

```text
out/bzImage          Linux kernel image
out/rootfs.cpio.gz   initramfs archive
build/rootfs/        generated root filesystem
```

## Repository Layout

```text
kernel/       kernel notes
rootfs/       source-controlled root filesystem template
initramfs/    early PID 1 init script
scripts/      reproducible build and run helpers
docs/         educational notes
configs/      kernel and userspace configuration fragments
qemu/         QEMU notes
build/        generated sources/rootfs
downloads/    downloaded upstream tarballs
out/          final boot artifacts
```

## Roadmap

1. Phase I: kernel + BusyBox + initramfs + shell in QEMU.
2. Phase II: rootfs layout, proc/sys/dev, hostname, boot logs, basic network.
3. Phase III: persistent block rootfs and controlled userspace startup.
4. Phase IV: toolchain with binutils, GCC, and musl/glibc.
5. Phase V: simple package manager, for example `mentat install htop`.
6. Phase VI: AWS flavor with awscli, Terraform, SSM Agent, kubectl, eksctl.
