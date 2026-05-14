# Roadmap

Mentat Linux advances in small milestones. Each phase should remain bootable,
documented, and reproducible.

## Phase I - Minimal Boot

Goal: boot in QEMU until a BusyBox shell appears.

Components:

- Vanilla Linux kernel.
- Statically compiled BusyBox.
- gzip-compressed `newc` initramfs.
- Minimal `/init`.
- `make run`.
- `make smoke`.

Done when QEMU reaches a shell.

## Phase II - Early Userspace

Goal: turn the rescue shell into a small but real early userspace.

Implemented:

- Root filesystem template in `rootfs/`.
- PID 1 script in `initramfs/init`.
- `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/var/log`, and `/root`.
- `procfs`, `sysfs`, and `devtmpfs` mounting.
- Hostname setup.
- QEMU user-mode networking with a virtio NIC.
- DHCP attempt through BusyBox `udhcpc`.
- Boot logging to `/var/log/boot.log`.
- Emergency shell loop if boot fails.

Done when QEMU prints:

```text
MENTAT_LINUX_PHASE2_BOOT_OK
mentat:/#
```

## Phase III - Persistent Root Block Device

Goal: move from "complete initramfs" to a root filesystem image mounted as
the real `/`.

Planned:

- ext4 root image.
- QEMU `-drive`.
- initramfs that mounts the block root and `switch_root`s.
- basic `/etc/fstab`.

## Phase IV - Toolchain

Goal: stop relying on the host toolchain for userspace.

Planned:

- binutils.
- GCC.
- musl or glibc.
- controlled sysroot.

## Phase V - Package Manager

Goal: install packages through a tiny native interface.

Example:

```sh
mentat install htop
```

## Phase VI - AWS Flavor

Goal: specialize the base for AWS SysOps work.

Candidates:

- awscli.
- Terraform.
- AWS SSM Agent.
- kubectl.
- eksctl.
- cloud-init.
- observability tools.
