# Overlay Profiles

AmazonSpiceOx now supports simple composable profiles on top of the Debian
mirror workflow.

Current profile components:

- `base`
- `debug`
- `ops`
- `aws`
- `awscli`
- `ssm`
- `terraform`
- `kubectl`
- `gui`
- `xpra`

`base` is always included automatically.

## What a Profile Changes

A profile affects two things:

1. package manifests
2. filesystem overlays

Examples:

```sh
make fetch ASOX_PROFILES="base debug"
sudo -E make rootfs ASOX_PROFILES="base debug"
make run ASOX_PROFILES="base debug"
```

```sh
make fetch ASOX_PROFILES="base ops"
sudo -E make rootfs ASOX_PROFILES="base ops"
make run ASOX_PROFILES="base ops"
```

```sh
make fetch ASOX_PROFILES="base aws"
sudo -E make rootfs ASOX_PROFILES="base aws"
make run ASOX_PROFILES="base aws"
```

```sh
make fetch ASOX_PROFILES="base aws awscli"
sudo -E make rootfs ASOX_PROFILES="base aws awscli"
make run ASOX_PROFILES="base aws awscli"
```

```sh
make fetch ASOX_PROFILES="base aws awscli ssm"
sudo -E make rootfs ASOX_PROFILES="base aws awscli ssm"
make run ASOX_PROFILES="base aws awscli ssm"
```

```sh
make fetch ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
sudo -E make rootfs ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
make run ASOX_PROFILES="base ops terraform" TERRAFORM_VERSION=1.15.5
```

```sh
make fetch ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
sudo -E make rootfs ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
make run ASOX_PROFILES="base ops kubectl" KUBECTL_VERSION=v1.36.1
```

```sh
make fetch ASOX_PROFILES="base gui"
sudo -E make rootfs ASOX_PROFILES="base gui"
make run-gui ASOX_PROFILES="base gui"
```

```sh
make fetch ASOX_PROFILES="base gui xpra"
sudo -E make rootfs ASOX_PROFILES="base gui xpra"
make run ASOX_PROFILES="base gui xpra"
```

## Current Layout

```text
rootfs/         -> base overlay
overlays/debug/ -> debug-specific overlay
overlays/ops/   -> ops-specific overlay
overlays/aws/   -> aws-specific overlay
overlays/terraform/ -> terraform-specific overlay
overlays/kubectl/ -> kubectl-specific overlay
overlays/gui/   -> gui-specific overlay
overlays/xpra/  -> xpra-specific overlay
```

The selected package lists come from:

```text
manifests/base.txt
manifests/debug.txt
manifests/ops.txt
manifests/aws.txt
manifests/awscli.txt
manifests-post/awscli.txt
manifests/ssm.txt
manifests/terraform.txt
manifests/kubectl.txt
manifests/gui.txt
manifests/xpra.txt
```

## Output Paths

The active profile is part of the generated output names.

Examples:

```text
build/rootfs-base/
out/rootfs-base.ext4

build/rootfs-base-debug/
out/rootfs-base-debug.ext4

build/rootfs-base-aws/
out/rootfs-base-aws.ext4
```

Inside the guest, the active profile is recorded in:

```text
/etc/amazonspiceox-profile
```

## Current Intent

- `base`: bootable minimal Debian rootfs
- `debug`: quality-of-life tools such as `curl`, `htop`, `jq`, `strace`, and
  `vim-tiny`
- `ops`: operator tools such as `bind9-dnsutils`, `curl`, `git`,
  `inetutils-telnet`, `jq`, and `vim`
- `aws`: first AWS-oriented package slice, including `cloud-guest-utils`,
  `jq`, and `openssh-client`
- `awscli`: optional add-on profile for `awscli`
- `ssm`: optional add-on profile for the AWS Session Manager plugin
- `terraform`: optional add-on profile for a version-pinned Terraform binary
- `kubectl`: optional add-on profile for a version-pinned kubectl client and
  kubeconfig helper flow
- `gui`: optional add-on profile for guest-side X11 launch, Chromium, and
  desktop Python runtimes
- `xpra`: optional add-on profile for forwarding guest GUI apps as individual
  windows to cross-platform host clients

`cloud-init` remains a later Phase VI candidate rather than part of this first
AWS profile cut.

The `awscli` profile is installed after the base Debian bootstrap rather than
through `debootstrap --include`.

The `ssm` profile is fetched from the official AWS Session Manager plugin Debian
package URL, verified with the AWS detached package signature and public key,
and installed after the Debian bootstrap.

The `terraform` profile is fetched from HashiCorp's official release archive,
verified with the signed `SHA256SUMS` metadata, and copied into
`/usr/local/bin/terraform`.

The `kubectl` profile is fetched from the official Kubernetes release channel,
validated with the published `kubectl.sha256` checksum, copied into
`/usr/local/bin/kubectl`, and paired with the `kubeconfig` helper.

The `gui` profile adds a small guest-side launcher stack:

- `gui-run`
- `chrome`
- `python-gui`

The `xpra` profile adds:

- the `xpra` server package inside the guest
- port-forwarded access from the host to the guest Xpra server
- `ASOX_GUI_BACKEND=xpra` by default when that profile is active
- `xpra-info` to show the attach command and active port

On Debian `trixie`, `xpra` itself is installed from the official Xpra
repository during the post-bootstrap package phase.
