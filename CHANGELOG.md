# Changelog

All notable progress in AmazonSpiceOx is tracked here.

## 2026-06-09 - v1.1 Usability and Integration Fixes

Implemented:

- serial QEMU console now uses stdio with `signal=off`, so `Ctrl+C` is passed
  to the guest instead of killing QEMU
- stage-2 login shells now `cd` into the active user's home directory and
  normalize basic TTY control keys before launching Bash
- base profile now includes `sudo` and `bash-completion`
- root profile sources Bash completion when available
- `sudoers.d` policy for root and future `sudo` group users
- QEMU host gateway aliases:
  `host.qemu.internal`, `host.local`, `host.docker.internal`, and
  `host.containers.internal`
- network smoke now validates the host gateway alias
- GUI profile now defaults `ASOX_GUI_BACKEND=auto`
- `asox-browser`, `xdg-open`, `x-www-browser`, and `sensible-browser` wrappers
  route browser launches to Chromium for AWS SSO and other auth flows
- `asox-terminal` now opens xterm with a dark theme, larger geometry, scrollbar,
  and `xterm-256color`
- release kernel command line defaults remove `earlyprintk` and add
  `quiet loglevel=3 tsc=unstable`
- release artifact naming now uses a clean flavor slug such as
  `amazonspiceox-0.1.0-amd64-full.tar.gz`, with full profile details kept in
  `BUILDINFO`

## 2026-06-07 - First Release Packaging

Implemented:

- `RELEASE_VERSION` and `ASOX_RELEASE_PROFILES` Makefile controls
- first complete release profile default:
  `base ops aws awscli ssm terraform kubectl docker ssm-powerconnect`
- `docker` profile with Debian `docker-cli` plus `docker.io`, `docker-start`,
  `docker-status`, cgroup v2 setup, and `make smoke-docker`
- `asox-console` backed by `tmux` for a usable scrollback buffer on the serial
  console
- `make release`, `make release-package`, and `make release-package-only`
- `scripts/build-release.sh` to create a self-contained QEMU bundle under
  `out/release/`
- release `run.sh`, `run-gui.sh`, `BUILDINFO`, `SHA256SUMS`, and compressed
  `.tar.gz` package generation
- release packaging guard that refuses images containing common AWS local state
  paths under `/root/.aws`
- manual GitHub Actions release workflow that uploads the release tarball as an
  artifact
- `docs/release.md`

Notes:

- the first release workflow uploads artifacts for manual inspection rather
  than publishing a GitHub Release automatically
- release images should be rebuilt from clean generated rootfs output before
  packaging
- Docker daemon startup is manual in this non-systemd guest:
  run `docker-start` inside arrakis when you need containers

## 2026-06-07 - SSM-PowerConnect App Profile

Implemented:

- `ssm-powerconnect` as a composite profile for the Tkinter AWS SSM desktop
  tool
- automatic profile implication for `gui`, `aws`, `awscli`, and `ssm` when
  `ssm-powerconnect` is selected
- GitHub-backed fetch of the `AmazonSpiceOx/` app folder from
  `Hugo-BerC/SSM-PowerConnect`
- installation of the app into `/opt/ssm-powerconnect`
- `/usr/local/bin/ssm-powerconnect` guest launcher through `python-gui`
- `make smoke-ssm-powerconnect` and `make smoke-ssm-powerconnect-only`
- AmazonSpiceOx UI polish patch for the app: cleaner dark layout, no stretched
  background image, stable PowerCon controls, and scrollable instance table

Notes:

- the smoke validates the launcher, app files, Python imports, and syntax
  without opening a GUI window
- runtime GUI behavior follows the existing `gui-run` / `python-gui` backend
  model

## 2026-06-05 - Minimal GUI Guest Layer

Implemented:

- the `gui` profile as an opt-in graphical guest layer
- `manifests/gui.txt` with Chromium, X11, `openbox`, and Python desktop
  runtime packages
- `make run-gui` and `make run-gui-only` for QEMU boots with a graphical
  window
- `gui-run` as a helper that launches a one-shot X11 session for a guest
  command
- `chrome` as a guest-facing wrapper around Debian's Chromium package
- `python-gui` as a guest-facing launcher for desktop Python scripts and quick
  Tkinter validation

Notes:

- this is intentionally not a full desktop environment
- the goal is to open a browser and desktop Python apps inside the VM while
  keeping the distro small and focused

## 2026-06-05 - Xpra Cross-Platform App Forwarding

Implemented:

- the `xpra` profile as an opt-in cross-platform forwarding layer on top of
  `gui`
- guest-side `xpra` packaging and default backend selection through
  `ASOX_GUI_BACKEND=xpra`
- `xpra-info` helper inside the guest
- QEMU host port forwarding for the Xpra server when the `xpra` profile is
  active
- `make xpra-attach` to connect a host Xpra client to the guest app stream

Notes:

- this is the preferred release path for showing Chromium and Tkinter windows
  on WSL and macOS hosts without relying on a full QEMU desktop window
- the guest still keeps host-X11 and local-X11 fallbacks, but `xpra` is the
  most portable direction for the first release

## 2026-06-05 - AWS Session Manager Plugin and Bash Login Shells

Implemented:

- the `ssm` profile as an opt-in AWS Session Manager plugin layer on top of
  `base aws awscli`
- official AWS Session Manager plugin `.deb` download caching under
  `downloads/external/`
- detached-signature verification of the Session Manager plugin package using
  the AWS-documented Linux signing key
- post-bootstrap installation of external `.deb` packages in
  `scripts/build-rootfs.sh`
- `make smoke-ssm` and `make smoke-ssm-only` to validate the Session Manager
  plugin inside the guest
- stage-2 interactive shells now prefer `/bin/bash --login` when `bash` is
  present in the rootfs
- `bash` added to the base Debian manifest so the default guest shell is more
  comfortable for interactive work

Notes:

- the Session Manager plugin stays outside `debootstrap --include` because it
  is not a Debian archive package; it is fetched from the official AWS Session
  Manager plugin URL and installed afterward
- `awscli` remains a separate post-bootstrap profile component because of the
  current `trixie` bootstrap issue around `python3-cryptography` and versioned
  `cffi` virtual dependencies

## 2026-06-05 - Operator Tools Review

Implemented:

- `ops` profile for general operator tooling that maps cleanly to Debian
  packages
- `manifests/ops.txt` with `bind9-dnsutils`, `curl`, `git`,
  `inetutils-telnet`, `jq`, and `vim`
- `overlays/ops/` profile marker so the guest can tell when the operator layer
  is active
- documentation that separates "straight Debian packages" from tools that need
  versioned or external installation flows

Notes:

- the RPM-world `bind-utils` name maps to `bind9-dnsutils` in Debian
- `telnet` is best represented by `inetutils-telnet` in current Debian
- `terraform`, `kubectl`, and `docker` were intentionally kept out of this
  Debian-only profile slice because they needed either version pinning,
  upstream repositories, or additional service-management work

## 2026-06-05 - Terraform External Profile

Implemented:

- `terraform` profile as a version-pinned external binary layer
- `TERRAFORM_VERSION` in the `Makefile`, defaulting to `1.15.5`
- external artifact fetch and verification for Terraform release archives
- `make smoke-terraform` and `make smoke-terraform-only`
- generic external rootfs file installation support in `scripts/build-rootfs.sh`

Notes:

- Terraform is fetched from HashiCorp's official release channel rather than
  from the Debian archive
- the selected archive checksum is verified against the signed `SHA256SUMS`
  metadata before the binary is installed into the guest

## 2026-06-05 - kubectl and kubeconfig Helper Layer

Implemented:

- `kubectl` profile as a version-pinned upstream Kubernetes client layer
- `KUBECTL_VERSION` in the `Makefile`, defaulting to `v1.36.1`
- official `dl.k8s.io` binary fetch with checksum verification
- `asox-kubeconfig` helper to initialize, inspect, and install kubeconfig files
- `make smoke-kubectl` and `make smoke-kubectl-only`

Notes:

- the `kubectl` profile exports `KUBECONFIG=/root/.kube/config`
- the helper keeps the guest-side kubeconfig workflow explicit without pulling
  in a larger Kubernetes packaging stack

## 2026-06-02 - Guest Apt Validation

Implemented:

- `awscli` promoted from "manifest only" to a first-class optional profile
  component.
- `awscli` now installs post-bootstrap with `apt` instead of through
  `debootstrap --include`.
- `make smoke-awscli` and `make smoke-awscli-only` to validate guest `awscli`
  behavior independently.
- `make run-only` to boot the current artifacts without implicitly rebuilding
  the rootfs or ext4 image.
- `make smoke-net` and `make smoke-net-only` to validate guest networking and
  DNS independently from `apt`.
- `make smoke-apt` to boot the guest and validate `apt` from inside
  AmazonSpiceOx.
- kernel command line support for `asox.smoke=apt`.
- kernel command line support for `asox.smoke=network`.
- in-guest `apt` smoke script under
  `rootfs/usr/local/lib/amazonspiceox/smoke/apt.sh`.
- in-guest network smoke script under
  `rootfs/usr/local/lib/amazonspiceox/smoke/network.sh`.
- `asox-netcheck` helper inside the guest for interactive network debugging.
- CI now runs the new guest apt smoke after the normal boot smoke.
- the initial `aws` profile was trimmed to keep `cloud-init` as a later
  Phase VI candidate instead of part of the first profile slice.

Notes:

- the apt smoke currently validates `apt-get update`, package policy lookup,
  and a `--download-only` reinstall of `ca-certificates`.
- this gives us an end-to-end check that networking, DNS, repository metadata,
  and package download behavior work from inside the guest.
- `awscli` was split out of `manifests/aws.txt` into `manifests/awscli.txt`
  so the `base+aws` profile can stay lighter and avoid current `debootstrap`
  failures seen on some hosts while resolving Python crypto dependencies.

## 2026-05-26 - Profile Composition

Implemented:

- `ASOX_PROFILES` support for composing rootfs builds from profile components.
- `base`, `debug`, and `aws` manifest support.
- profile-specific overlays under `overlays/`.
- profile-aware rootfs and ext4 image output paths.
- `/etc/amazonspiceox-profile` written into the generated guest rootfs.
- stage-2 init now reports the active profile at boot.
- `/etc/profile.d` sourcing added to the base shell profile.
- package cache validation tightened to inspect Debian package metadata and
  contents when `dpkg-deb` is available.

Notes:

- `base` is always included automatically.
- The current next validation target is checking `apt` behavior inside the
  guest, now that profile composition exists.

## 2026-05-25 - Debian Stable Mirror Pivot

Implemented:

- Debian Stable became the new upstream package base.
- Alpine-specific bootstrap pieces were removed from the primary path.
- `configs/debian/sources.list` was added for pinned Debian repositories.
- `make fetch` now uses `debootstrap --download-only` to cache `.deb`
  packages from a public mirror.
- `make rootfs` now builds the distro rootfs with `debootstrap` plus
  AmazonSpiceOx overlays.
- `scripts/build-rootfs.sh` now writes a Debian-style `apt` sources list into
  the generated image.
- `rootfs/sbin/init` was adjusted to prefer Debian networking tools such as
  `ifup`.
- `initramfs/init` and `rootfs/sbin/init` now fall back cleanly when
  `cttyhack` is not present.
- Manifests were converted to Debian package names.
- Documentation and repo guidance were updated around the Debian workflow.

Notes:

- The package-driven rootfs model is now the default strategy.
- The old BusyBox-compiled rootfs path remains available as `make legacy-rootfs`
  for reference and for the tiny initramfs build.
- The earlier toolchain work remains in the repo as educational material, but
  it is no longer the default distro assembly path.

## Phase I - Minimal Boot

Date: 2026-05

Implemented:

- Vanilla Linux kernel download and build automation.
- BusyBox build automation.
- Minimal initramfs packaging.
- Minimal `/init` as PID 1.
- QEMU boot through `make run`.
- Smoke-testable boot marker.

Result:

```text
AWS SysOps Linux - Milestone 1
AWS_SYSOPS_LINUX_BOOT_OK
asl:/#
```

Notes:

- This was the first successful end-to-end boot.
- The project later evolved in naming and architecture, but this phase proved
  the kernel, BusyBox, initramfs, and QEMU pipeline.

## Phase II - Early Userspace

Date: 2026-05

Implemented:

- Root filesystem template in `rootfs/`.
- Cleaner early userspace init in `initramfs/init`.
- Mounting of `procfs`, `sysfs`, and `devtmpfs`.
- Runtime directories such as `/run`, `/tmp`, `/var/log`, and `/root`.
- Hostname configuration.
- Basic network bring-up with BusyBox tools and DHCP attempt.
- Boot logging and emergency shell handling.
- Dedicated scripts for rootfs, initramfs, and QEMU execution.

Result:

```text
AmazonSpiceOx - Phase II
AMAZONSPICEOX_PHASE2_BOOT_OK
arrakis:/#
```

Notes:

- The distro name became `AmazonSpiceOx`.
- The default hostname became `arrakis`.
- This phase turned the boot shell into a small but coherent early userspace.

## Phase III - Persistent Root Filesystem

Date: 2026-05

Implemented:

- Persistent ext4 root image at `out/rootfs.ext4`.
- QEMU virtio block device attachment.
- Initramfs stage 1 that reads `root=` and runs `switch_root`.
- Stage 2 `/sbin/init` running from the persistent rootfs.
- Basic `/etc/fstab`.
- Persistent root marker in `/var/lib/amazonspiceox/rootfs-state`.
- Reusable root disk behavior so `make run` does not recreate the disk unless
  the image is rebuilt explicitly.

Result:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

Notes:

- This is the first phase where writes can persist across reboots.
- The initramfs is no longer "the whole distro"; it is now the stage-1 boot
  environment that hands off to the real root filesystem.

## Historical Phase IV - Toolchain Bootstrap

Date: 2026-05

Implemented:

- Dedicated toolchain layout under `build/toolchain/`.
- Dedicated sysroot at `build/toolchain/sysroot`.
- Kernel headers export target for the sysroot.
- Cross-binutils bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- GCC stage 1 bootstrap target for `x86_64-amazonspiceox-linux-musl`.
- musl bootstrap target installing libc into the sysroot.
- GCC stage 2 target rebuilding the cross C compiler against musl.
- Static hello-world smoke target built by the cross-toolchain.
- Rootfs injection target so the toolchain hello-world can run inside
  AmazonSpiceOx.
- zlib bootstrap and smoke targets.
- OpenSSL bootstrap and smoke targets.

Notes:

- This work remains useful for learning and experimentation.
- It is no longer the default path for assembling the distro root filesystem.
