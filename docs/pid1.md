# PID 1 Responsibilities

PID 1 is special. It is the first userspace process started by the kernel.

In a full distro, PID 1 is often `systemd`, OpenRC, runit, or another init
system.

In AmazonSpiceOx Phase III, there are two PID 1 moments:

- Stage 1: `/init` from initramfs starts as PID 1.
- Stage 2: `/sbin/init` from the ext4 rootfs replaces it through `switch_root`.

Stage 1 responsibilities:

- Mount `/proc`, `/sys`, and `/dev`.
- Read `root=`, `rootfstype=`, `ro`, and `rw` from `/proc/cmdline`.
- Wait for the root block device.
- Mount the persistent root at `/newroot`.
- Execute `switch_root /newroot /sbin/init`.

Stage 2 responsibilities:

- Create runtime directories.
- Mount `/proc`.
- Mount `/sys`.
- Mount `/dev`.
- Configure `/tmp` permissions.
- Configure the hostname.
- Try to initialize basic networking.
- Write boot logs.
- Start an interactive shell.
- Avoid exiting.

The last point matters: if PID 1 exits, Linux treats it as a fatal condition.
For this reason, both init scripts open recovery shells instead of exiting.
If something important fails, it opens an emergency shell.
