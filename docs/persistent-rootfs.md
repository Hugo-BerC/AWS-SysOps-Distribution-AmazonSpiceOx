# Persistent Root Filesystem

Phase III introduces `out/rootfs.ext4`.

Before this phase, the whole system lived in initramfs. That means the root
filesystem was unpacked into RAM at boot and disappeared when QEMU exited.

Now the boot path is:

```text
kernel
  -> initramfs /init
  -> mount /dev/vda on /newroot
  -> switch_root /newroot /sbin/init
  -> persistent ext4 userspace
```

## Building the Image

`scripts/build-root-disk.sh` creates the image:

```sh
truncate -s 256M out/rootfs.ext4
mke2fs -t ext4 -F -L ASOXROOT -d build/rootfs out/rootfs.ext4
```

In the current Debian-based workflow, the script also measures the generated
rootfs and grows the requested image size automatically when 256 MB is not
enough.

The `-d build/rootfs` option is the key detail. It populates the ext4 image
from a directory without mounting loop devices and without using `sudo`.

## Why virtio

QEMU attaches the disk with:

```text
-drive file=out/rootfs.ext4,if=virtio,format=raw
```

Inside the guest, this appears as:

```text
/dev/vda
```

That is why the kernel config includes built-in virtio block support and QEMU
passes:

```text
root=/dev/vda rootfstype=ext4 rw
```

## Persistence Rule

Files written inside the running VM persist while `out/rootfs.ext4` is reused.
They disappear when you rebuild the root disk image.

`make run` reuses the existing image. To intentionally reset the persistent
root, remove it and rebuild:

```sh
rm -f out/rootfs.ext4
make root-disk
```
