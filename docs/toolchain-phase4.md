# Phase IV - Toolchain Plan

Phase IV is the point where AmazonSpiceOx starts reducing dependence on the
host compiler and moves toward a controlled userspace toolchain.

## Goal

Build a minimal cross-toolchain that can target AmazonSpiceOx consistently.

Recommended target triple:

```text
x86_64-amazonspiceox-linux-musl
```

## Incremental Plan

1. Create a dedicated sysroot under `build/toolchain/sysroot`.
2. Export kernel headers into that sysroot.
3. Build binutils for the target triple.
4. Build a stage-1 GCC without full libc support.
5. Build musl into the sysroot.
6. Rebuild GCC as a stage-2 compiler against musl.
7. Build a small real package into the sysroot.

## Current Progress

Implemented in the repo:

1. `make toolchain-sysroot` exports kernel headers into `build/toolchain/sysroot`.
2. `make binutils` builds cross-binutils into `build/toolchain/tools`.
3. `make gcc-stage1` builds a freestanding cross C compiler and the minimal
   target `libgcc` runtime needed by musl.
4. `make musl` installs musl into the sysroot.
5. `make gcc-stage2` rebuilds the C compiler against the musl sysroot.
6. `make toolchain-hello` produces a static smoke-test binary.
7. `make zlib` installs the first nontrivial package into the sysroot.
8. `make zlib-smoke` proves that package can be linked into a static target
   binary.
9. `make openssl` installs the first crypto/TLS dependency into the sysroot.
10. `make openssl-smoke` proves that package can be linked into a static target
    binary.

Pending:

1. first HTTP client or transfer-oriented package.
2. eventual language/runtime expansion beyond C when it is actually needed.

## Why This Order

- Kernel headers define the userspace/kernel ABI.
- binutils provides assembler and linker support first.
- GCC stage 1 is enough to compile libc pieces.
- GCC stage 1 disables `gcov` so `libgcc` does not pull in profiling runtime
  pieces that are irrelevant at this bootstrap stage.
- GCC stage 1 uses `--with-newlib` so it can still install the minimal target
  `libgcc` pieces that musl needs for compiler builtins.
- musl gives the toolchain a real libc and startup files.
- GCC stage 2 produces the usable C compiler for later phases.
- A tiny static hello-world is the cheapest possible end-to-end confidence
  check before moving on to real packages.
- zlib is a good first real package because it is small, common, and useful as
  a dependency for later tools without introducing a large dependency graph.
- OpenSSL on the `3.5` LTS branch is the next sensible layer because it brings
  in real crypto and TLS capabilities without forcing us to solve a full HTTP
  client stack in the same step.

## Expected Outputs

```text
build/toolchain/
  |- sysroot/
  |- tools/
  `- sources/
```

Example binaries after progress:

```text
build/toolchain/tools/bin/x86_64-amazonspiceox-linux-musl-as
build/toolchain/tools/bin/x86_64-amazonspiceox-linux-musl-ld
build/toolchain/tools/bin/x86_64-amazonspiceox-linux-musl-gcc
build/toolchain/tools/lib/gcc/x86_64-amazonspiceox-linux-musl/14.3.0/libgcc.a
out/toolchain-hello
build/toolchain/sysroot/usr/include/zlib.h
build/toolchain/sysroot/usr/lib/libz.a
out/zlib-smoke
build/toolchain/sysroot/usr/include/openssl/ssl.h
build/toolchain/sysroot/usr/lib/libcrypto.a
out/openssl-smoke
```

## Version Note

This bootstrap uses `musl 1.2.5`, which the musl site lists as the latest
official release. The same site also carries a security advisory for releases
through `1.2.5` related to `CVE-2025-26519`.

For AmazonSpiceOx this is acceptable as an educational bootstrap baseline, but
the libc version should be revisited before treating the distro as a hardened
runtime base.

## Host Build Dependencies

On Debian or Ubuntu systems, `gcc-stage1` typically needs:

```sh
sudo apt install libgmp-dev libmpfr-dev libmpc-dev
```

The `OpenSSL` package step also needs:

```sh
sudo apt install perl libtext-template-perl
```

## Definition of Done

Phase IV is in good shape when:

- We can compile a small static hello-world with the AmazonSpiceOx toolchain.
- We can build at least one real upstream package into the sysroot.
- We can build a crypto/TLS dependency into the sysroot.
- The resulting binary runs inside AmazonSpiceOx.
- The repo no longer depends on the host compiler for core userspace growth.
