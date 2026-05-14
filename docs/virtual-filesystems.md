# procfs, sysfs, and devtmpfs

Early userspace mounts a few special filesystems before the system becomes
useful.

## procfs

Mounted at `/proc`.

`procfs` exposes process and kernel runtime information. Tools such as `ps`
read from `/proc` to discover running processes.

## sysfs

Mounted at `/sys`.

`sysfs` exposes the kernel's device model. It is how userspace can inspect
devices, drivers, buses, and many kernel objects.

## devtmpfs

Mounted at `/dev`.

`devtmpfs` is populated by the kernel with device nodes such as consoles,
TTYs, disks, and network-related devices. Without a useful `/dev`, interactive
userspace is fragile because basic character devices may be missing.

AmazonSpiceOx mounts these from `initramfs/init` because there is no systemd or
full init system yet.
