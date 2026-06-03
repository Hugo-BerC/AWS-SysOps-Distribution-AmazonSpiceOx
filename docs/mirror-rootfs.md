# Mirror-Based Rootfs

AmazonSpiceOx now treats binary-package rootfs assembly as the primary build
path.

The project keeps its custom kernel, initramfs, stage-1 `/init`, stage-2
`/sbin/init`, and QEMU flow, but stops treating local userspace compilation as
the default.

## Current Shape

The current mirror-based implementation uses Debian Stable packages from the
public repositories configured in
[configs/debian/sources.list](../configs/debian/sources.list).

Main pieces:

- [manifests/base.txt](../manifests/base.txt)
- [manifests/debug.txt](../manifests/debug.txt)
- [manifests/aws.txt](../manifests/aws.txt)
- [docs/overlay-profiles.md](overlay-profiles.md)
- [scripts/fetch-packages.sh](../scripts/fetch-packages.sh)
- [scripts/build-rootfs.sh](../scripts/build-rootfs.sh)
- [scripts/verify-packages.sh](../scripts/verify-packages.sh)
- [scripts/update-mirrors.sh](../scripts/update-mirrors.sh)

## Pipeline

```text
Debian mirror
  -> debootstrap package download cache
  -> Debian rootfs assembly
  -> AmazonSpiceOx overlays
  -> initramfs
  -> ext4 image
  -> QEMU
```

## Make Targets

```sh
make profile-info
make fetch
make verify-packages
sudo -E make rootfs
make initramfs
sudo -E make image
make run
make smoke-apt
```

## Notes

- `make fetch` is meant to be cheap and repeatable.
- `make rootfs` currently requires root privileges because `debootstrap`
  creates a real Debian filesystem tree.
- `ASOX_PROFILES` selects which manifests and overlays are composed into the
  generated rootfs.
- `make smoke-apt` validates that `apt` can refresh metadata and download a
  package from inside the guest.
- the current apt smoke retries `apt-get update` and asks the guest to power
  off once the validation ends.
- The legacy toolchain path still exists in the repo for educational reference.
- The legacy BusyBox-only rootfs path still exists as `make legacy-rootfs`.
