# AmazonSpiceOx

AmazonSpiceOx is an educational Linux distribution built from small, explicit
pieces: vanilla Linux, BusyBox, initramfs, early userspace, a persistent ext4
root filesystem, and QEMU.

The long-term direction is an AWS SysOps-oriented distro, but the immediate
goal is learning Linux internals deeply and reproducibly.

## Current Status

Phase III is complete.
Phase IV is in progress.

AmazonSpiceOx now boots in two stages:

1. `initramfs/init` runs as stage 1, mounts `/proc`, `/sys`, and `/dev`,
   discovers `/dev/vda`, mounts it at `/newroot`, and runs `switch_root`.
2. `/sbin/init` runs from the ext4 root filesystem as the real stage 2 init,
   configures early userspace, networking, hostname, boot logs, and launches a
   BusyBox shell.

Expected marker:

```text
AmazonSpiceOx - Phase III
AMAZONSPICEOX_PHASE3_BOOT_OK
arrakis:/#
```

## Build

On WSL or Linux:

Base dependencies:

```sh
sudo apt install -y \
  build-essential bc bison flex libssl-dev libelf-dev cpio curl xz-utils \
  bzip2 gzip make qemu-system-x86 musl-tools file ca-certificates \
  e2fsprogs
```

Additional dependencies for Phase IV toolchain bootstrap:

```sh
sudo apt install -y libgmp-dev libmpfr-dev libmpc-dev
```

Basic distro build:

```sh
make deps
make all
make run
```

Useful targets:

```sh
make toolchain-sysroot  # export kernel headers into build/toolchain/sysroot
make binutils           # build cross-binutils for x86_64-amazonspiceox-linux-musl
make gcc-stage1         # build the stage-1 cross C compiler and minimal libgcc
make gcc-stage2         # rebuild the cross C compiler against musl
make musl               # install musl into the Phase IV sysroot
make toolchain          # bootstrap the current Phase IV toolchain through GCC stage 2
make toolchain-hello    # build a static hello-world with the cross-toolchain
make toolchain-hello-rootfs  # inject hello-world into the persistent rootfs image
make rootfs     # build build/rootfs from rootfs/ + BusyBox + initramfs/init
make initramfs  # package build/rootfs as out/rootfs.cpio.gz
make root-disk  # build out/rootfs.ext4 from build/rootfs
make run        # boot QEMU with kernel + initramfs + ext4 root disk
make smoke      # boot briefly and check the Phase III marker
make clean
```

## Output

```text
out/bzImage          Linux kernel image
out/rootfs.cpio.gz   initramfs stage 1 archive
out/rootfs.ext4      persistent ext4 root filesystem image
build/rootfs/        generated root filesystem tree
build/toolchain/     Phase IV sysroot, tools, and sources
out/toolchain-hello  static smoke-test binary built by the cross-toolchain
```

## Boot Flow

`make run` uses `scripts/run-qemu.sh`, which starts QEMU with:

```sh
qemu-system-x86_64 \
  -kernel out/bzImage \
  -initrd out/rootfs.cpio.gz \
  -append "console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw" \
  -display none \
  -serial mon:stdio \
  -no-reboot \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0 \
  -drive file=out/rootfs.ext4,if=virtio,format=raw
```

The boot path is:

```text
kernel
  -> initramfs /init
  -> mount /dev/vda on /newroot
  -> switch_root /newroot /sbin/init
  -> persistent ext4 userspace
```

## Repository Layout

```text
kernel/       kernel notes
rootfs/       source-controlled root filesystem template
initramfs/    stage 1 initramfs PID 1 script
scripts/      reproducible build and run helpers
docs/         educational notes
configs/      kernel and userspace configuration fragments
qemu/         QEMU notes
build/        generated sources/rootfs
downloads/    downloaded upstream tarballs
out/          final boot artifacts
```

## Changelog

Project history is tracked in [CHANGELOG.md](<C:/Users/hugo.bermejo/Desktop/Terraform/AWS-SysOps-Distribution/CHANGELOG.md>).

## Roadmap

1. Phase I: kernel + BusyBox + initramfs + shell in QEMU.
2. Phase II: rootfs layout, proc/sys/dev, hostname, boot logs, basic network.
3. Phase III: persistent block rootfs and controlled userspace startup.
4. Phase IV: toolchain with binutils, GCC, and musl/glibc.
5. Phase V: simple package manager, for example `amazonspiceox install htop`.
6. Phase VI: AWS flavor with awscli, Terraform, SSM Agent, kubectl, eksctl.

## Next Phase

The next logical step is Phase IV: build a controlled userspace toolchain so
AmazonSpiceOx stops depending on the host compiler for future packages.

The most realistic incremental path is:

1. Build and install kernel headers into a dedicated sysroot.
2. Build `binutils` for a target prefix such as `x86_64-amazonspiceox-linux-musl`.
3. Build a minimal stage-1 GCC.
4. Build musl against that sysroot.
5. Rebuild GCC and target runtime pieces as the stage-2 compiler.

That keeps the project understandable and avoids jumping straight into a full
"Linux From Scratch" leap in one commit.

Detailed notes for this phase live in [docs/toolchain-phase4.md](<C:/Users/hugo.bermejo/Desktop/Terraform/AWS-SysOps-Distribution/docs/toolchain-phase4.md>).

Today, the repo already includes the first two pieces of that bootstrap:

```text
build/toolchain/sysroot
build/toolchain/tools/bin/x86_64-amazonspiceox-linux-musl-ld
```

The current bootstrap now reaches:

```text
build/toolchain/tools/bin/x86_64-amazonspiceox-linux-musl-gcc
build/toolchain/tools/lib/gcc/x86_64-amazonspiceox-linux-musl/14.3.0/libgcc.a
```

`gcc-stage1` is configured with `--disable-gcov` so the bootstrap avoids
building `libgcov` pieces that are not useful in this freestanding stage.
It also uses `--with-newlib` so stage 1 can install the minimal target
`libgcc` runtime pieces that musl needs for compiler builtins like
`__mulsc3` and `__mulxc3`.

Once `make gcc-stage2` finishes, the same tool prefix is rebuilt against the
musl-populated sysroot and becomes the main C compiler for the next steps.

For a first proof that the toolchain is usable end to end:

```sh
make toolchain
make toolchain-hello
file out/toolchain-hello
```

To run that binary inside AmazonSpiceOx:

```sh
make toolchain-hello-rootfs
make run
```

Then inside `arrakis:/#`:

```sh
/usr/local/bin/hello-toolchain
```

If the toolchain bootstrap needs to be retried cleanly, the smallest reset is:

```sh
rm -rf build/toolchain
make toolchain
```

For the current libc bootstrap, the repo uses `musl 1.2.5`, which is still the
latest official release on the musl site. The musl project also publishes a
security advisory stating that releases through `1.2.5` should be patched for
`CVE-2025-26519`, so this version should be treated as an educational bootstrap
base rather than a production-hardened final choice.

Those `libgmp-dev`, `libmpfr-dev`, and `libmpc-dev` packages are required for
`make gcc-stage1`, `make gcc-stage2`, and `make toolchain`.

## Learning Check

After booting, try:

```sh
mount
ps
hostname
ip addr
cat /var/log/boot.log
cat /var/lib/amazonspiceox/rootfs-state
echo survives-rebuild > /root/persistence-test
sync
```

The file written under `/root` is inside `out/rootfs.ext4`. It persists across
QEMU reboots as long as you do not delete or rebuild `out/rootfs.ext4`.
