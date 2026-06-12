# Release Packaging

AMZSpiceOx release packaging produces a self-contained QEMU test bundle:

- `bzImage`
- `rootfs.cpio.gz`
- `rootfs.ext4`
- `run.sh`
- `run-gui.sh`
- `scripts/run-qemu.sh`
- `BUILDINFO`
- `SHA256SUMS`

The first complete release profile is:

```text
base ops aws awscli ssm terraform kubectl docker ssm-powerconnect
```

`ssm-powerconnect` automatically adds `gui`; the AWS CLI and Session Manager
layers are listed explicitly in the release profile for readability.

## Local Build

```bash
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make fetch
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make verify-packages
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make rootfs
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make initramfs
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make image
sudo -E ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make release-package-only
```

Output:

```text
out/release/
```

The default release flavor is `full`, so the first complete image is packaged
as:

```text
amzspiceox-<version>-amd64-full.tar.gz
```

Detailed profile metadata remains in `BUILDINFO`.

Release packaging also emits WSL import assets next to the QEMU bundle:

```text
amzspiceox-<version>-amd64-full-wsl-rootfs.tar.gz
amzspiceox-<version>-amd64-full-install-wsl.ps1
```

## Smoke Tests

Recommended pre-release checks:

```bash
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-net-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-awscli-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-ssm-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-terraform-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-kubectl-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-docker-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-ssm-powerconnect-only
ASOX_PROFILES="base ops aws awscli ssm terraform kubectl docker ssm-powerconnect" make smoke-apt-only
```

## Run A Release

```bash
tar -xf amzspiceox-1.0.0-amd64-*.tar.gz
cd amzspiceox-1.0.0-amd64-*
sh run-gui.sh
```

Inside arrakis:

```bash
ASOX_GUI_BACKEND=local-x11 ssm-powerconnect
```

The graphical release launcher defaults to Spanish keyboard layout. Override it
from the host when needed:

```bash
QEMU_KEYBOARD_LAYOUT=us sh run-gui.sh
```

## Import Into WSL

From PowerShell:

```powershell
.\amzspiceox-1.0.0-amd64-full-install-wsl.ps1
wsl -d AMZSpiceOx
```

Manual import:

```powershell
wsl --import AMZSpiceOx "$env:LOCALAPPDATA\AMZSpiceOx\wsl" .\amzspiceox-1.0.0-amd64-full-wsl-rootfs.tar.gz --version 2
wsl -d AMZSpiceOx
```

WSL mode uses the host WSL kernel. The bundled `bzImage`, initramfs, and QEMU
wrappers are only used by the QEMU release flow.

## Secret Guard

The packager refuses to create a release when it detects these paths in the
rootfs directory or ext4 image:

```text
/root/.aws/config
/root/.aws/credentials
/root/.aws/sso
```

Rebuild the image from a clean generated rootfs before packaging if you used a
test image with personal AWS config.
