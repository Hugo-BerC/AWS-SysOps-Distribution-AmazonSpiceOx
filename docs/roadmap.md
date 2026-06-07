# Roadmap

AmazonSpiceOx advances in small milestones. Each phase should remain bootable,
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
AMAZONSPICEOX_PHASE2_BOOT_OK
arrakis:/#
```

## Phase III - Persistent Root Block Device

Goal: move from "complete initramfs" to a root filesystem image mounted as
the real `/`.

Implemented:

- ext4 root image.
- QEMU `-drive`.
- initramfs stage 1 that mounts the block root and runs `switch_root`.
- stage 2 `/sbin/init` inside the persistent rootfs.
- basic `/etc/fstab`.
- persistent marker under `/var/lib/amazonspiceox/rootfs-state`.

Done when QEMU prints:

```text
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

## Phase IV - Debian Stable Rootfs

Goal: assemble the root filesystem from upstream Debian packages instead of
compiling the base userspace locally.

Current direction:

- Debian Stable repositories pinned in `configs/debian/sources.list`.
- Manifest-driven package selection under `manifests/`.
- `debootstrap --download-only` to cache packages locally.
- `debootstrap` rootfs assembly plus AmazonSpiceOx overlays.
- Existing initramfs and persistent ext4 image flow reused on top.

Done when:

- `make fetch` populates the Debian package cache.
- `sudo -E make rootfs` generates a bootable Debian-based rootfs.
- `make run` still reaches `arrakis:/#`.

Validation:

- `make smoke-net` now boots the guest, validates basic networking and DNS from
  inside AmazonSpiceOx, and checks for `AMAZONSPICEOX_NETWORK_SMOKE_OK`.
- `make smoke-apt` now boots the guest, runs an `apt` validation pass from
  inside AmazonSpiceOx, and checks for `AMAZONSPICEOX_APT_SMOKE_OK`.

## Phase V - Overlay Profiles

Goal: compose AmazonSpiceOx personalities from manifests and overlays.

Initial implementation:

- `ASOX_PROFILES="base debug"` support.
- `ASOX_PROFILES="base aws"` support.
- profile-specific rootfs and image output paths.
- active profile recorded in `/etc/amazonspiceox-profile`.

Examples:

```text
base + debug
base + aws
base + aws + security
```

## Legacy - Toolchain Bootstrap

The GCC/musl/toolchain work remains valuable, but it is no longer the default
path for assembling the distro root filesystem.

## Phase VI - AWS Flavor

Goal: specialize the base for AWS SysOps work.

Candidates:

- awscli
- Terraform
- Docker Engine / Docker CLI
- AWS SSM Agent
- kubectl
- eksctl
- cloud-init
- observability tools

Current first cut:

- `ASOX_PROFILES="base ops"` for a fuller operator toolbox inside the guest
- `ASOX_PROFILES="base aws"` for a lightweight AWS-oriented guest
- `ASOX_PROFILES="base aws awscli"` for an opt-in AWS CLI layer
- `ASOX_PROFILES="base aws awscli ssm"` for an opt-in Session Manager plugin
  layer on top of the AWS CLI
- `ASOX_PROFILES="base ops terraform"` for a version-pinned Terraform layer
- `ASOX_PROFILES="base ops kubectl"` for a version-pinned kubectl client plus
  kubeconfig helper layer
- `ASOX_PROFILES="base gui"` for a minimal X11-capable guest that can launch
  Chromium and desktop Python apps without a full desktop environment
- `ASOX_PROFILES="base gui xpra"` for forwarding Chromium and Tkinter apps to
  WSL and macOS hosts as individual windows
- `make smoke-awscli` / `make smoke-awscli-only` to validate the AWS CLI
- `make smoke-ssm` / `make smoke-ssm-only` to validate the Session Manager
  plugin inside the guest
- `make smoke-terraform` / `make smoke-terraform-only` to validate Terraform
  inside the guest
- `make smoke-kubectl` / `make smoke-kubectl-only` to validate kubectl and
  kubeconfig helpers inside the guest
- the `awscli` layer is installed post-bootstrap with `apt` rather than through
  `debootstrap --include`
- the `ssm` layer is fetched from AWS, signature-verified, and installed
  post-bootstrap because it does not come from the Debian archive
- the `terraform` layer is fetched from HashiCorp releases, checksum-verified,
  and pinned through `TERRAFORM_VERSION`
- the `kubectl` layer is fetched from `dl.k8s.io`, checksum-verified, and
  pinned through `KUBECTL_VERSION`

Next recommended slices:

- `docker`: official Docker Debian repo packages, paired with a later service
  management phase because this guest does not use systemd
