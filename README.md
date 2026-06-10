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
- composable `base`, `debug`, `ops`, `aws`, `awscli`, `ssm`, `terraform`,
  `kubectl`, and `docker` profile building
- optional `gui` profile for Chromium, X11 app launch, and desktop Python
  runtimes
- optional `xpra` profile for cross-platform forwarding of individual guest GUI
  apps to WSL or macOS hosts
- optional `ssm-powerconnect` profile for the Tkinter-based AWS SSM desktop
  tool
- interactive login shells now prefer `/bin/bash` when it is present in the
  guest rootfs

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
  e2fsprogs \
  gnupg \
  unzip \
  patch
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
make run-gui
make xpra-attach
```

Avoid `sudo -E make all` for regular local work. It can leave source trees in
`build/src/` owned by root, which then breaks later non-root rebuilds.

Expected boot marker:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

To exit QEMU cleanly from inside the guest:

```text
poweroff
```

In the normal interactive shell, `exit` or `Ctrl+D` also asks the guest to
power off.

The serial console passes `Ctrl+C` through to the guest, so it behaves like a
normal Linux interrupt instead of closing QEMU. If the guest is not responding,
close the host terminal or stop the QEMU process from another terminal.

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
make run-only
make run-gui
make run-gui-only
make xpra-attach
make release
make release-package-only
make smoke
make smoke-net
make smoke-awscli
make smoke-ssm
make smoke-ssm-powerconnect
make smoke-terraform
make smoke-kubectl
make smoke-docker
make smoke-apt
```

Useful extras:

```text
make profile-info
make run-only
make smoke-only
make smoke-net-only
make smoke-awscli-only
make smoke-ssm-only
make smoke-ssm-powerconnect-only
make smoke-terraform-only
make smoke-kubectl-only
make smoke-docker-only
make smoke-apt-only
make run-gui-only
make legacy-rootfs
make clean
make distclean
```

`legacy-rootfs` keeps the older BusyBox-compiled rootfs flow around as
educational reference. It is also still useful for the tiny initramfs build.

`run-only`, `smoke-only`, `smoke-net-only`, `smoke-awscli-only`,
`smoke-ssm-only`, `smoke-docker-only`, and `smoke-apt-only` reuse the current
artifacts without rebuilding the rootfs or ext4 image. They are useful after a
`sudo -E make rootfs` / `sudo -E make image` cycle when you only want to re-run
QEMU-side validation.

## First Release Package

The first complete release profile is:

```text
base ops aws awscli ssm terraform kubectl docker ssm-powerconnect
```

`ssm-powerconnect` also automatically implies `gui`, so the full resolved
profile includes the browser/Tkinter GUI runtime, AWS CLI, Session Manager
plugin, Terraform, kubectl, kubeconfig helpers, Docker, and SSM-PowerConnect.

Build and package it locally:

```bash
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make fetch
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make verify-packages
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make rootfs
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make initramfs
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make image
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make release-package-only
```

The release package is written under:

```text
out/release/
```

Release artifacts use a short flavor name by default, for example:

```text
amazonspiceox-0.1.0-amd64-full.tar.gz
```

The full resolved profile is recorded inside `BUILDINFO`.

The packager refuses to publish images containing common local AWS state paths
such as `/root/.aws/config`, `/root/.aws/credentials`, or `/root/.aws/sso`.

To run an unpacked release:

```bash
tar -xf amazonspiceox-0.1.0-amd64-*.tar.gz
cd amazonspiceox-0.1.0-amd64-*
sh run-gui.sh
```

Inside the guest:

```bash
ASOX_GUI_BACKEND=local-x11 ssm-powerconnect
```

### WSL Import

Release packaging also emits a sibling WSL rootfs archive and installer:

```text
amazonspiceox-0.1.0-amd64-full-wsl-rootfs.tar.gz
amazonspiceox-0.1.0-amd64-full-install-wsl.ps1
```

Import it from PowerShell:

```powershell
.\amazonspiceox-0.1.0-amd64-full-install-wsl.ps1
wsl -d AmazonSpiceOx
```

Or manually:

```powershell
wsl --import AmazonSpiceOx "$env:LOCALAPPDATA\AmazonSpiceOx\wsl" .\amazonspiceox-0.1.0-amd64-full-wsl-rootfs.tar.gz --version 2
wsl -d AmazonSpiceOx
```

In WSL mode, AmazonSpiceOx uses the host WSL kernel instead of the bundled QEMU
kernel/initramfs. On Windows with WSLg, GUI apps such as `chromium` and
`ssm-powerconnect` can open directly without `run-gui.sh`.

## Profiles and Manifests

The rootfs is package-driven and profile-aware.

Current manifests:

- `manifests/base.txt`
- `manifests/aws.txt`
- `manifests/awscli.txt`
- `manifests/ops.txt`
- `manifests/ssm.txt`
- `manifests/terraform.txt`
- `manifests/kubectl.txt`
- `manifests/xpra.txt`
- `manifests/ssm-powerconnect.txt`
- `manifests/gui.txt`
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
make fetch ASOX_PROFILES="base ops"
sudo -E make rootfs ASOX_PROFILES="base ops"
make run ASOX_PROFILES="base ops"
```

```bash
make fetch ASOX_PROFILES="base aws"
sudo -E make rootfs ASOX_PROFILES="base aws"
make run ASOX_PROFILES="base aws"
```

```bash
make fetch ASOX_PROFILES="base aws awscli"
sudo -E make rootfs ASOX_PROFILES="base aws awscli"
make run ASOX_PROFILES="base aws awscli"
```

```bash
make fetch ASOX_PROFILES="base aws awscli ssm"
sudo -E make rootfs ASOX_PROFILES="base aws awscli ssm"
make run ASOX_PROFILES="base aws awscli ssm"
```

```bash
make fetch ASOX_PROFILES="base ops terraform"
sudo -E make rootfs ASOX_PROFILES="base ops terraform"
make run ASOX_PROFILES="base ops terraform"
```

```bash
make fetch ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
sudo -E make rootfs ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
make run ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
```

```bash
make fetch ASOX_PROFILES="base ops docker"
sudo -E make rootfs ASOX_PROFILES="base ops docker"
make run ASOX_PROFILES="base ops docker"
```

```bash
make fetch ASOX_PROFILES="base gui"
sudo -E make rootfs ASOX_PROFILES="base gui"
make initramfs
sudo -E make image ASOX_PROFILES="base gui"
make run-gui-only ASOX_PROFILES="base gui"
```

```bash
make fetch ASOX_PROFILES="base gui xpra"
sudo -E make rootfs ASOX_PROFILES="base gui xpra"
make initramfs
sudo -E make image ASOX_PROFILES="base gui xpra"
make run-only ASOX_PROFILES="base gui xpra"
```

```bash
make fetch ASOX_PROFILES="base ssm-powerconnect"
make verify-packages
sudo -E make rootfs ASOX_PROFILES="base ssm-powerconnect"
make initramfs
sudo -E make image ASOX_PROFILES="base ssm-powerconnect"
make smoke-ssm-powerconnect-only ASOX_PROFILES="base ssm-powerconnect"
make run-gui-only ASOX_PROFILES="base ssm-powerconnect"
```

Package names are standard Debian package names.
`base` is always included automatically.
The current `aws` profile is intentionally lightweight and keeps the first
Debian bootstrap focused on packages that behave well under `debootstrap`.
The `ops` profile is the main place for day-to-day operator tools that map
cleanly to Debian packages.
`awscli` and the heavy Docker daemon package currently live in post-bootstrap
manifests:

```text
manifests-post/awscli.txt
manifests-post/docker.txt
```

That means:

- `ASOX_PROFILES="base ops"` gives you the general-purpose operator toolkit
- `ASOX_PROFILES="base aws"` gives you the light AWS-oriented slice
- `ASOX_PROFILES="base aws awscli"` adds the AWS CLI on top
- `ASOX_PROFILES="base aws awscli ssm"` adds the AWS Session Manager plugin on
  top of the AWS CLI layer
- `ASOX_PROFILES="base ops terraform"` adds a version-pinned Terraform binary
- `ASOX_PROFILES="base ops kubectl"` adds a version-pinned `kubectl` client
  plus kubeconfig helpers
- `ASOX_PROFILES="base ops docker"` adds Debian `docker-cli`, `docker.io`,
  Docker helpers, and guest-side cgroup setup for manual daemon startup
- `ASOX_PROFILES="base gui"` adds a minimal X11-capable guest with Chromium
  and desktop Python launch helpers
- `ASOX_PROFILES="base gui xpra"` adds an Xpra server path for forwarding
  individual guest windows to WSL or macOS hosts
- `ASOX_PROFILES="base ssm-powerconnect"` adds the SSM-PowerConnect Tkinter
  app and automatically pulls in `gui`, `aws`, `awscli`, and `ssm`
- `cloud-init` stays as a later Phase VI candidate

Current package mapping:

- `bind-utils` on RPM-based distros maps to `bind9-dnsutils` here
- `telnet` is provided by `inetutils-telnet`
- `vim` is now the full `vim` package in the `ops` profile rather than
  `vim-tiny`
- `curl`, `git`, `jq`, and `tmux` are straight Debian packages
- `terraform` is an externally fetched HashiCorp release archive with explicit
  version pinning through `TERRAFORM_VERSION`
- `kubectl` is an externally fetched upstream Kubernetes client with explicit
  version pinning through `KUBECTL_VERSION`
- Docker is provided by Debian's split `docker-cli` and `docker.io` packages,
  installed after the base bootstrap, and launched manually with
  `docker-start` because AmazonSpiceOx does not use systemd
- `chromium`, `xinit`, `Xorg`, and Python GUI bits live in the opt-in `gui`
  profile
- `xpra` lives in its own opt-in profile so the forwarding path stays explicit
  and releasable across WSL and macOS
- on Debian `trixie`, the `xpra` profile installs `xpra` from the official
  Xpra repository after the base bootstrap, while keeping `xvfb` in the normal
  Debian package set
- the post-bootstrap `xpra` install also includes `xpra-x11`, which upstream
  recommends on Debian for seamless X11 app forwarding
- `ssm-powerconnect` fetches the `AmazonSpiceOx/` app folder from
  `https://github.com/Hugo-BerC/SSM-PowerConnect` and installs it into
  `/opt/ssm-powerconnect` with a `/usr/local/bin/ssm-powerconnect` launcher

Terraform example:

```bash
make fetch ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
sudo -E make rootfs ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
make smoke-terraform-only ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
```

Implementation detail:

- `terraform` is fetched from `releases.hashicorp.com`
- the `SHA256SUMS` file is verified against HashiCorp's signing key
- the selected archive checksum is verified before the binary is copied into
  `/usr/local/bin/terraform`

kubectl example:

```bash
make fetch ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
sudo -E make rootfs ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
make smoke-kubectl-only ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
```

Implementation detail:

- `kubectl` is fetched from `dl.k8s.io`
- the upstream `kubectl.sha256` file is used for validation before the binary
  is copied into `/usr/local/bin/kubectl`
- AmazonSpiceOx also includes `kubeconfig` and exports
  `KUBECONFIG=/root/.kube/config` when the `kubectl` profile is active

Docker example:

```bash
make fetch ASOX_PROFILES="base ops docker"
sudo -E make rootfs ASOX_PROFILES="base ops docker"
sudo -E make image ASOX_PROFILES="base ops docker"
make smoke-docker-only ASOX_PROFILES="base ops docker"
make run-only ASOX_PROFILES="base ops docker"
```

Inside arrakis:

```bash
docker-status
docker-start
docker run --rm hello-world
```

Implementation detail:

- Docker comes from Debian's split `docker-cli` and `docker.io` packages
- it is installed in the post-bootstrap package phase so service start attempts
  are blocked cleanly during image assembly
- AmazonSpiceOx mounts cgroup v2 during stage-2 init when the kernel supports
  it
- `docker-start` runs `dockerd` manually and logs to `/var/log/docker.log`
- if daemon startup fails on iptables setup while tuning the kernel, retry with
  `DOCKER_IPTABLES=false docker-start`
- the default storage driver is `vfs` for broad QEMU compatibility; override it
  with `DOCKER_STORAGE_DRIVER=overlay2 docker-start` when the kernel/image
  combination supports overlayfs cleanly

Example with the optional AWS CLI manifest:

```bash
make fetch DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt"
sudo -E make rootfs DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt" DEBIAN_POST_MANIFESTS="manifests-post/awscli.txt"
make run DEBIAN_MANIFESTS="manifests/base.txt manifests/aws.txt" DEBIAN_POST_MANIFESTS="manifests-post/awscli.txt"
```

That optional manifest flow still works, but the preferred path is now the
profile form:

```bash
make fetch ASOX_PROFILES="base aws awscli"
sudo -E make rootfs ASOX_PROFILES="base aws awscli"
make smoke-awscli-only ASOX_PROFILES="base aws awscli"
```

Implementation detail:

- `awscli` is installed after the base Debian bootstrap with `apt`, not through
  `debootstrap --include`
- this avoids a current `trixie` bootstrap failure around `python3-cryptography`
  and versioned `cffi` virtual dependencies
- `ssm` is fetched from the official AWS Session Manager plugin Debian package
  URL, validated against the official AWS signing key and detached signature,
  and then installed post-bootstrap

The active profile also changes the generated rootfs and image paths. For
example:

```text
build/rootfs-base-debug/
out/rootfs-base-debug.ext4
```

## Graphical Apps

AmazonSpiceOx can now launch guest GUI apps without committing to a full
desktop environment.

The `gui` profile installs:

- `chromium`
- `xinit`
- `Xorg`
- `openbox`
- `xterm`
- `asox-terminal`
- `x11-xkb-utils`
- `python3`
- `python3-pip`
- `python3-venv`
- `python3-tk`

When the `gui` profile is active, AmazonSpiceOx now defaults QEMU memory to
`2048M` instead of `512M`, because Chromium is not happy in a half-gig guest.

There are two GUI modes:

1. host-forwarded X11, where guest apps open directly on your desktop
2. guest-local X11, where QEMU opens a graphical VM window

There is now a third mode aimed at release portability:

3. `xpra`, where the guest app is exported as an individual remote window and
   attached from the host with an Xpra client

For host-forwarded X11, run an X server on the Windows host that listens on
TCP and then boot the guest normally:

```bash
make fetch ASOX_PROFILES="base gui"
make verify-packages
sudo -E make rootfs ASOX_PROFILES="base gui"
make initramfs
sudo -E make image ASOX_PROFILES="base gui"
make run-only ASOX_PROFILES="base gui"
```

Inside the guest:

```bash
gui-doctor
chrome
python-gui
python-gui /root/my-app.py
gui-run xterm
```

By default, `gui-run` and the wrappers built on top of it return your shell
prompt immediately and leave the GUI process running in the background. For a
foreground debugging run, prefix the command with:

```bash
ASOX_GUI_WAIT=1
```

The guest defaults `DISPLAY` to `10.0.2.2:0`, so the only missing piece in
that mode is the host X server.

If you want the fallback mode with a QEMU window instead, use:

```bash
make run-gui-only ASOX_PROFILES="base gui"
```

`chrome` is intentionally a thin wrapper around Debian's `chromium` package so
we can keep the workflow package-driven and reproducible while still giving you
a Chrome-like browser inside the VM.

### Keyboard and Console UX

Graphical QEMU boots default to a Spanish keyboard layout:

```bash
QEMU_KEYBOARD_LAYOUT=es make run-gui-only ASOX_PROFILES="base gui"
```

Inside guest X11 sessions, AmazonSpiceOx also applies:

```bash
ASOX_KEYBOARD_LAYOUT=es
```

Override either variable if you need another layout. The serial `run.sh`
console is different: it receives characters from the host terminal, so its
keyboard behavior is controlled mostly by Windows Terminal, WSL, macOS
Terminal, or whatever terminal is running QEMU.

For graphical terminal windows, use `asox-terminal` or `gui-run` without
arguments. It wraps `xterm` with a visible scrollbar and larger scrollback:

```bash
gui-run
gui-run asox-terminal
```

If mouse wheel scrolling in the serial console repeats shell history instead
of moving through scrollback, use the host terminal scrollbar or start a
graphical terminal with `ASOX_GUI_BACKEND=local-x11 gui-run asox-terminal`.
`asox-terminal` defaults to a dark xterm theme, larger geometry, and
`xterm-256color`, which improves full-screen tools such as Vim.

If Vim keys behave strangely, run:

```bash
asox-termcheck
```

AmazonSpiceOx defaults to `TERM=xterm-256color`, disables XON/XOFF flow control
so `Ctrl+S` does not freeze the terminal, and ships Vim defaults for Backspace,
Escape timing, and terminal key handling.

For a better serial-console buffer, run:

```bash
asox-console
```

That attaches to a `tmux` session with mouse support and a larger scrollback.
Inside tmux, use `Ctrl+b` then `[` for copy/scroll mode, or the mouse wheel
when your host terminal forwards mouse events.

### QEMU Performance

`scripts/run-qemu.sh` defaults `QEMU_ACCEL=auto`:

- Linux/WSL uses KVM when `/dev/kvm` is available to the current user.
- macOS Intel uses HVF.
- everything else falls back to multi-threaded TCG emulation.

Check acceleration from the host with:

```bash
ls -l /dev/kvm
```

If `/dev/kvm` is missing or not writable in WSL, QEMU will be much slower. You
can add your Linux user to the `kvm` group, then restart WSL:

```bash
sudo usermod -aG kvm "$USER"
```

From PowerShell:

```powershell
wsl --shutdown
```

After reopening WSL, confirm that `id` shows `kvm`. You can force behavior with:

```bash
QEMU_ACCEL=kvm make run-only ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect"
QEMU_ACCEL=tcg make run-only ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect"
```

### Host Gateway

QEMU user-mode networking exposes the host gateway at `10.0.2.2`. AmazonSpiceOx
also writes common aliases into `/etc/hosts`:

```text
host.qemu.internal
host.local
host.docker.internal
host.containers.internal
```

When QEMU runs from WSL, the launcher also detects the Windows host IP from
WSL's resolver and adds:

```text
host.os.internal
host.windows.internal
host.wsl.internal
```

For a host service listening on port `8000`, test from arrakis with:

```bash
curl http://host.qemu.internal:8000/
curl http://host.windows.internal:8000/
```

The service must listen on an address reachable from QEMU, not only on an
unreachable loopback namespace. On Windows, prefer binding test services to
`0.0.0.0` or the Windows host IP instead of only `127.0.0.1`, and allow the
port through the firewall.

For host-to-guest access, use QEMU port forwarding:

```bash
QEMU_HOSTFWD_EXTRA="tcp:127.0.0.1:2222-:22" make run-only ASOX_PROFILES="base ops"
```

Run `asox-netcheck` inside arrakis to print all detected host aliases and basic
connectivity checks.

### Clipboard

Serial console paste is controlled by the host terminal. In graphical mode,
AmazonSpiceOx installs `spice-vdagent`, and QEMU enables the vdagent clipboard
channel automatically when the host QEMU supports `qemu-vdagent`.

Clipboard support applies to GUI sessions launched with `make run-gui-only` and
guest X11 apps. It does not make the raw serial console behave like a desktop
terminal emulator.

Inside a GUI session, diagnose the channel with:

```bash
asox-clipboard doctor
```

Fallback for password fields when host clipboard sync is not working: open an
`asox-terminal` inside the guest GUI and run:

```bash
asox-clipboard set
```

Paste the secret into the hidden prompt, press Enter, then focus Chromium and
press `Ctrl+V`. This sets the guest X11 clipboard without echoing the value
back to the terminal.

### Xpra Mode

The `xpra` profile is the recommended release path for WSL and macOS hosts.

Build and boot:

```bash
make fetch ASOX_PROFILES="base gui xpra"
make verify-packages
sudo -E make rootfs ASOX_PROFILES="base gui xpra"
make initramfs
sudo -E make image ASOX_PROFILES="base gui xpra"
make run-only ASOX_PROFILES="base gui xpra"
```

Inside the guest:

```bash
xpra-info
chrome
python-gui
python-gui /root/my-app.py
ssm-powerconnect
```

From the host, attach with:

```bash
make xpra-attach ASOX_PROFILES="base gui xpra"
```

or directly:

```bash
xpra attach tcp://127.0.0.1:14500/
```

This works because QEMU forwards host port `14500` to the guest `xpra` server
when the `xpra` profile is active.

### SSM-PowerConnect

`ssm-powerconnect` is a composite profile for the Tkinter AWS SysOps tool.

It implies:

- `gui`
- `aws`
- `awscli`
- `ssm`

Build and validate:

```bash
make fetch ASOX_PROFILES="base ssm-powerconnect"
make verify-packages
sudo -E make rootfs ASOX_PROFILES="base ssm-powerconnect"
make initramfs
sudo -E make image ASOX_PROFILES="base ssm-powerconnect"
make smoke-ssm-powerconnect-only ASOX_PROFILES="base ssm-powerconnect"
```

Run it inside the guest:

```bash
ssm-powerconnect
```

The app is installed in `/opt/ssm-powerconnect` and launched through
`python-gui`, so it follows the same GUI backend rules as `chrome` and other
Tkinter apps.

AWS SSO browser flows use the same browser plumbing. The GUI profile exports
`BROWSER=/usr/local/bin/asox-browser`, and the guest provides `xdg-open`,
`x-www-browser`, and `sensible-browser` wrappers that launch Chromium.

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

When `bash` is present in the guest, AmazonSpiceOx now prefers a login
`/bin/bash` session for the interactive shell. If `bash` is missing, it falls
back to `/bin/sh`.

For the `kubectl` profile, the kubeconfig helper works like this:

```bash
kubeconfig status
kubeconfig init
kubeconfig install /path/to/config
cat my-kubeconfig.yaml | kubeconfig install-stdin
```

## Documentation

Start here:

- [docs/boot-process.md](docs/boot-process.md)
- [docs/overlay-profiles.md](docs/overlay-profiles.md)
- [docs/release.md](docs/release.md)
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

If `apt-get update` reports repository signatures like:

```text
Not live until ...
The repository ... InRelease is not signed
```

the WSL or VM clock is behind the timestamp on Debian's signed metadata.
Restarting WSL normally refreshes the clock:

```powershell
wsl --shutdown
```

Then open WSL again and rerun the build. The post-bootstrap package installer
also uses a temporary base-only Debian source list during image assembly to
avoid `trixie-security` and `trixie-updates` clock skew blocking packages such
as `awscli` and `docker.io`.

Inside AmazonSpiceOx, check guest/host clock drift with:

```bash
asox-timecheck
```

QEMU launches pass the host UTC epoch to the guest and use an UTC RTC by
default. To override the RTC manually:

```bash
QEMU_RTC="base=utc,clock=host" make run-only ASOX_PROFILES="$PROFILE"
```

If DNS resolution fails inside AmazonSpiceOx, repair the resolver with:

```bash
asox-dns-fix
asox-netcheck
```

The default resolver order is Google DNS, Cloudflare DNS, then QEMU's user-mode
DNS proxy when running under QEMU. WSL release images disable automatic
`resolv.conf` regeneration so the fallback resolver remains persistent.

If WSL itself drifts after suspend or around midday, restart the WSL VM from
PowerShell:

```powershell
wsl --shutdown
wsl -d AmazonSpiceOx
```

If Bash prints locale warnings such as:

```text
setlocale: LC_CTYPE: cannot change locale (en_US.UTF-8)
```

rebuild the rootfs with the current base manifest. The image now includes
`locales` and generates both `en_US.UTF-8` and `es_ES.UTF-8` during rootfs
assembly.

```bash
PROFILE="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect"
sudo -E make rootfs ASOX_PROFILES="$PROFILE"
sudo -E make image ASOX_PROFILES="$PROFILE"
```

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
