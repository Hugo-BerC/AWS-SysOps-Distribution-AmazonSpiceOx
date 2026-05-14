# Initramfs Lifecycle

An initramfs is a root filesystem archive loaded by the bootloader or virtual
machine monitor and handed to the Linux kernel.

Mentat Linux builds it like this:

1. `scripts/build-rootfs.sh` creates `build/rootfs`.
2. BusyBox is installed into that generated rootfs.
3. `initramfs/init` is copied to `build/rootfs/init`.
4. `scripts/build-initramfs.sh` packs `build/rootfs` as `newc` cpio.
5. The cpio archive is compressed as `out/rootfs.cpio.gz`.
6. QEMU passes the archive to the kernel with `-initrd`.

At boot time, the kernel unpacks the archive into memory. In Phase II, this
initramfs is the whole system. In a later phase, it will become an early boot
environment that mounts a persistent disk root and then hands control to it.

The important file is `/init`. If `/init` is missing, not executable, or cannot
run, the kernel has no PID 1 and boot fails.
