# AmazonSpiceOx

AmazonSpiceOx is an educational Linux distribution built from small, explicit
pieces: vanilla Linux, BusyBox, initramfs, early userspace, a persistent ext4
root filesystem, and QEMU.

The long-term direction is an AWS SysOps-oriented distro, but the immediate
goal is learning Linux internals deeply and reproducibly.

## Current Status

Phase III: persistent root filesystem and controlled userspace startup.

The system now boots in two stages:

1. `initramfs/init` runs as stage 1, mounts `/proc`, `/sys`, and `/dev`,
   discovers `/dev/vda`, mounts it at `/newroot`, and runs `switch_root`.
2. `/sbin/init` runs from the ext4 root filesystem as the real stage 2 init,
   configures early userspace, networking, hostname, boot logs, and launches a
   BusyBox shell.

Expected marker:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
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
make root-disk  # build out/rootfs.ext4 from build/rootfs
make run        # boot QEMU with kernel + initramfs + ext4 root disk
make smoke      # boot briefly and check the Phase III marker
make clean
```

## Output

```text
out/bzImage          Linux kernel image
out/rootfs.cpio.gz   initramfs stage 1 archive
out/rootfs.ext4      persistent ext4 root filesystem image
build/rootfs/        generated root filesystem tree
```

## Boot Command

`make run` uses `scripts/run-qemu.sh`, which starts QEMU with:

```sh
qemu-system-x86_64 \
  -kernel out/bzImage \
  -initrd out/rootfs.cpio.gz \
  -append "console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw" \
  -display none \
  -serial mon:stdio \
  -no-reboot \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -drive file=out/rootfs.ext4,if=virtio,format=raw
```

## Repository Layout

```text
kernel/       kernel notes
rootfs/       source-controlled root filesystem template
initramfs/    stage 1 initramfs PID 1 script
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
5. Phase V: simple package manager, for example `amazonspiceox install htop`.
6. Phase VI: AWS flavor with awscli, Terraform, SSM Agent, kubectl, eksctl.

## Learning Check

After booting, try:

```sh
mount
ps
hostname
ip addr
cat /var/log/boot.log
cat /var/lib/amazonspiceox/rootfs-state
echo survives-rebuild > /root/persistence-test
sync
```

The file written under `/root` is inside `out/rootfs.ext4`. It persists across
QEMU reboots as long as you do not delete or rebuild `out/rootfs.ext4`.
