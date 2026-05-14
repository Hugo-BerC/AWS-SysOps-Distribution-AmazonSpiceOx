# Early Userspace Concepts

Early userspace is the small environment that runs immediately after the kernel
finishes its own initialization.

In AmazonSpiceOx, early userspace is intentionally simple:

- BusyBox provides core commands.
- `/init` is a readable stage 1 shell script in initramfs.
- `/sbin/init` is a readable stage 2 shell script in the persistent rootfs.
- The root filesystem image is generated from `rootfs/`.
- QEMU provides a serial console and a virtual network device.

The goal is not comfort yet. The goal is transparency: every boot step should
be visible and explainable.

## Networking

QEMU starts with user-mode networking:

```text
-netdev user,id=net0
-device virtio-net-pci,netdev=net0
```

The kernel needs the virtio network driver built in, because this system does
not load external kernel modules yet.

Inside `/sbin/init`, AmazonSpiceOx:

1. Brings up loopback.
2. Tries to bring up `eth0`.
3. Runs BusyBox `udhcpc`.
4. Uses `rootfs/usr/share/udhcpc/default.script` to apply the DHCP lease.

If DHCP fails, boot continues and the log is left in `/tmp/udhcpc.log`.
