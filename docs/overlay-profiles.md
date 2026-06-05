# Overlay Profiles

AmazonSpiceOx now supports simple composable profiles on top of the Debian
mirror workflow.

Current profile components:

- `base`
- `debug`
- `aws`
- `awscli`

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
make fetch ASOX_PROFILES="base aws"
sudo -E make rootfs ASOX_PROFILES="base aws"
make run ASOX_PROFILES="base aws"
```

```sh
make fetch ASOX_PROFILES="base aws awscli"
sudo -E make rootfs ASOX_PROFILES="base aws awscli"
make run ASOX_PROFILES="base aws awscli"
```

## Current Layout

```text
rootfs/         -> base overlay
overlays/debug/ -> debug-specific overlay
overlays/aws/   -> aws-specific overlay
```

The selected package lists come from:

```text
manifests/base.txt
manifests/debug.txt
manifests/aws.txt
manifests/awscli.txt
manifests-post/awscli.txt
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
- `aws`: first AWS-oriented package slice, including `cloud-guest-utils`,
  `jq`, and `openssh-client`
- `awscli`: optional add-on profile for `awscli`

`cloud-init` remains a later Phase VI candidate rather than part of this first
AWS profile cut.

The `awscli` profile is installed after the base Debian bootstrap rather than
through `debootstrap --include`.
