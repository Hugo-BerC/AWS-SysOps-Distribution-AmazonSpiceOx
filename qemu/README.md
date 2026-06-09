# QEMU

QEMU is launched through `scripts/run-qemu.sh`.

The default machine uses:

- x86_64 kernel boot with `-kernel`.
- gzip-compressed initramfs with `-initrd`.
- persistent ext4 root disk with `-drive file=out/rootfs.ext4,if=virtio`.
- serial console through stdio with host signal handling disabled, so `Ctrl+C`
  reaches the guest.
- no graphical display.
- user-mode networking with a virtio network device.
- automatic acceleration with KVM on Linux/WSL when `/dev/kvm` is usable, HVF
  on macOS Intel, and TCG fallback.
- optional graphical clipboard via QEMU vdagent when `QEMU_GUI=1` and the host
  QEMU supports `qemu-vdagent`.

Set `QEMU_DEBUG=1` to wait for a debugger on TCP port 1234:

```sh
QEMU_DEBUG=1 make run
```
