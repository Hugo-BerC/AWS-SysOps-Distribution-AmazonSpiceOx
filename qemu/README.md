# QEMU

QEMU is launched through `scripts/run-qemu.sh`.

The default machine uses:

- x86_64 kernel boot with `-kernel`.
- gzip-compressed initramfs with `-initrd`.
- persistent ext4 root disk with `-drive file=out/rootfs.ext4,if=virtio`.
- serial console through stdio.
- no graphical display.
- user-mode networking with a virtio network device.

Set `QEMU_DEBUG=1` to wait for a debugger on TCP port 1234:

```sh
QEMU_DEBUG=1 make run
```
