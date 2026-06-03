# AmazonSpiceOx

AmazonSpiceOx is an educational Linux distribution project focused on boot flow,
root filesystem assembly, and cloud-oriented systems engineering.

The project started as a Linux-from-scratch style exercise. The current
direction is more practical:

- keep the custom kernel and initramfs flow
- keep the persistent ext4 root filesystem image
- stop compiling the whole userspace locally by default
- assemble the rootfs from upstream binary packages
- add AmazonSpiceOx overlays on top

That gives us a project that is still low-level and educational, but much
faster to iterate on.

## Why Debian Stable

AmazonSpiceOx now uses Debian Stable as its upstream package base.

Why Debian instead of Alpine or Arch:

- Debian Stable has a large package archive
- `glibc` compatibility is friendlier for AWS tooling and common server
  software
- `debootstrap` gives us a clean, official rootfs bootstrap path
- Debian is easier to keep reproducible than a rolling-release base
- the package model matches the goal of "assemble, overlay, boot, validate"

The default suite in this repo is currently:

```text
trixie
```

You can change it through `DEBIAN_SUITE` in the `Makefile` or on the command
line.

## Architecture

Current boot and image flow:

```text
Debian mirror
  -> package download cache
  -> debootstrap rootfs assembly
  -> AmazonSpiceOx overlays
  -> custom initramfs
  -> ext4 root disk
  -> QEMU
```

Current runtime flow:

```text
Linux kernel
  -> initramfs /init
  -> mount /dev/vda
  -> switch_root
  -> /sbin/init
  -> arrakis:/#
```

## Repository Layout

```text
amazonspiceox/
|- configs/
|  `- debian/
|- docs/
|- initramfs/
|- kernel/
|- manifests/
|- overlays/
|- packages/
|- qemu/
|- rootfs/
|- scripts/
|- build/
|- downloads/
`- out/
```

Important directories:

- `rootfs/`: base overlay copied into the generated Debian rootfs
- `overlays/`: optional profile-specific overlays
- `initramfs/`: stage-1 boot userspace
- `manifests/`: package lists for rootfs composition
- `configs/debian/`: Debian package source configuration
- `scripts/`: reproducible build helpers

## Current Status

Implemented:

- vanilla Linux kernel build in QEMU
- custom initramfs with stage-1 `/init`
- persistent ext4 root filesystem
- stage-2 `/sbin/init`
- boot logging and basic network bring-up
- Debian Stable rootfs assembly through `debootstrap`
- manifest-driven package selection
- composable `base`, `debug`, and `aws` profile building

Still intentionally small:

- no systemd dependency
- no installer
- no package manager replacement yet
- no AWS-specific overlay profile enabled by default

## Build Requirements

On Debian or Ubuntu hosts, install:

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  bc \
  bison \
  flex \
  libssl-dev \
  libelf-dev \
  cpio \
  curl \
  xz-utils \
  bzip2 \
  gzip \
  make \
  qemu-system-x86 \
  debootstrap \
  binutils \
  file \
  ca-certificates \
  e2fsprogs
```

Run a host check with:

```bash
make deps
```

Notes:

- `make fetch` can run unprivileged
- `make rootfs` requires `sudo` because `debootstrap` creates a real Debian
  filesystem tree
- `make image` is safest under `sudo` as well, because the generated rootfs can
  contain root-owned paths such as `/root`
- the ext4 image builder auto-grows the image when the requested size is too
  small for the generated Debian rootfs

## Quick Start

From WSL or Linux:

```bash
make profile-info
make fetch
make verify-packages
sudo -E make rootfs
make initramfs
sudo -E make image
make run
```

Avoid `sudo -E make all` for regular local work. It can leave source trees in
`build/src/` owned by root, which then breaks later non-root rebuilds.

Expected boot marker:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

To exit QEMU in `-nographic` mode:

```text
Ctrl+a, then x
```

## Make Targets

Main targets:

```text
make deps
make fetch
make verify-packages
make rootfs
make initramfs
make image
make run
make smoke
make smoke-apt
```

Useful extras:

```text
make profile-info
make legacy-rootfs
make clean
make distclean
```

`legacy-rootfs` keeps the older BusyBox-compiled rootfs flow around as
educational reference. It is also still useful for the tiny initramfs build.

## Profiles and Manifests

The rootfs is package-driven and profile-aware.

Current manifests:

- `manifests/base.txt`
- `manifests/aws.txt`
- `manifests/awscli.txt`
- `manifests/debug.txt`

Default build:

```text
ASOX_PROFILES=base
```

Examples:

```bash
make fetch ASOX_PROFILES="base debug"
sudo -E make rootfs ASOX_PROFILES="base debug"
make run ASOX_PROFILES="base debug"
```

```bash
make fetch ASOX_PROFILES="base aws"
sudo -E make rootfs ASOX_PROFILES="base aws"
make run ASOX_PROFILES="base aws"
```

Package names are standard Debian package names.
`base` is always included automatically.
The current `aws` profile is intentionally lightweight and keeps the first
Debian bootstrap focused on packages that behave well under `debootstrap`.
`awscli` currently lives in its own optional manifest:

```text
manifests/awscli.txt
```

That means:

- `ASOX_PROFILES="base aws"` gives you the light AWS-oriented slice
- `awscli` is opt-in for now
- `cloud-init` stays as a later Phase VI candidate

Example with the optional AWS CLI manifest:

```bash
make fetch DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt manifests/awscli.txt"
sudo -E make rootfs DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt manifests/awscli.txt"
make run DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt manifests/awscli.txt"
```

The active profile also changes the generated rootfs and image paths. For
example:

```text
build/rootfs-base-debug/
out/rootfs-base-debug.ext4
```

## Rootfs Strategy

AmazonSpiceOx no longer treats local userspace compilation as the default path.

The preferred workflow is:

1. download packages from a public Debian mirror
2. cache them locally
3. assemble a minimal rootfs with `debootstrap`
4. apply AmazonSpiceOx overlays from `rootfs/` and optional profile overlays
5. boot and validate in QEMU

This keeps the project understandable while removing a lot of unnecessary
compiler bootstrap friction.

## Networking

The current rootfs overlay expects a simple Debian-style network config:

- loopback enabled
- `eth0` via DHCP
- `ifupdown` preferred
- fallback logic in `/sbin/init` for simpler environments

Hostname defaults to:

```text
arrakis
```

## Documentation

Start here:

- [docs/boot-process.md](docs/boot-process.md)
- [docs/overlay-profiles.md](docs/overlay-profiles.md)
- [docs/mirror-rootfs.md](docs/mirror-rootfs.md)
- [docs/persistent-rootfs.md](docs/persistent-rootfs.md)
- [docs/roadmap.md](docs/roadmap.md)
- [CHANGELOG.md](CHANGELOG.md)

## Troubleshooting

If you ever see source extraction errors like:

```text
tar: ... Cannot open: File exists
tar: ... Cannot change mode ... Operation not permitted
```

that usually means a previous build path ran with `sudo` and left parts of
`build/`, `downloads/`, or `out/` owned by root.

Fix it in WSL with:

```bash
sudo chown -R "$USER:$USER" build downloads out
```

Then rerun the normal flow without `sudo` except for `make rootfs` and
`make image`.

## Legacy Toolchain Work

The repo still contains the earlier toolchain bootstrap work:

- `make toolchain-sysroot`
- `make binutils`
- `make gcc-stage1`
- `make musl`
- `make gcc-stage2`

That work remains useful for learning, but it is no longer the main path for
building the distro rootfs.

## Design Principles

AmazonSpiceOx aims to stay:

- explicit
- reproducible
- small enough to understand
- close to the boot process
- useful for AWS and systems learning

Avoid by default:

- hidden build abstractions
- large framework layers
- systemd-specific assumptions
- source-based rebuilds of the whole userspace
- rolling-release instability in the base distro

## Next Direction

Near-term goals:

- add AWS-focused packages from Debian where practical
- introduce custom package/install tooling only where it genuinely adds value
- validate `apt` behavior inside the guest with the profile-based rootfs flow

Longer-term goals:

- cloud-init support
- AMI-friendly image outputs
- immutable or semi-immutable rootfs variants
- a clearer AmazonSpiceOx package and profile model
