# Initramfs Lifecycle

An initramfs is a root filesystem archive loaded by the bootloader or virtual
machine monitor and handed to the Linux kernel.

AmazonSpiceOx builds it like this:

1. `scripts/build-rootfs.sh` creates a profile-specific rootfs directory such
   as `build/rootfs-base`.
2. BusyBox is installed into that generated rootfs.
3. `initramfs/init` is copied to the generated rootfs as `/init`.
4. `scripts/build-initramfs.sh` packs the BusyBox-based initramfs root as
   `newc` cpio.
5. The cpio archive is compressed as `out/rootfs.cpio.gz`.
6. `scripts/build-root-disk.sh` also turns the active profile rootfs into a
   profile-specific ext4 image such as `out/rootfs-base.ext4`.
7. QEMU passes the archive to the kernel with `-initrd`.
8. QEMU attaches the ext4 image as `/dev/vda`.

At boot time, the kernel unpacks the archive into memory. In Phase III, the
initramfs is stage 1 only. It mounts the persistent ext4 root filesystem and
then hands control to `/sbin/init` with `switch_root`.

For simplicity, Phase III still builds the initramfs from the same generated
tree as the ext4 image. Only `/init` is used before `switch_root`; the real
long-lived userspace is `/sbin/init` on the active profile ext4 image.

The important file is `/init`. If `/init` is missing, not executable, or cannot
run, the kernel has no PID 1 and boot fails.

The second important file is `/sbin/init` inside the persistent root image. If the disk
mounts but `/sbin/init` is missing, stage 1 drops into an emergency shell.
