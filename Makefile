PROJECT := amazonspiceox
empty :=
space := $(empty) $(empty)

KERNEL_ARCH ?= x86
KERNEL_DEFCONFIG ?= x86_64_defconfig
LINUX_VERSION ?= 6.6.1
DEBIAN_SUITE ?= trixie
DEBIAN_ARCH ?= amd64
DEBIAN_MIRROR ?= https://deb.debian.org/debian
ASOX_PROFILES ?= base
BUSYBOX_VERSION ?= 1.36.1
BINUTILS_VERSION ?= 2.46.0
GCC_VERSION ?= 14.3.0
MUSL_VERSION ?= 1.2.5
ZLIB_VERSION ?= 1.3.2
OPENSSL_VERSION ?= 3.5.6

BUILD_DIR := build
DL_DIR := downloads
SRC_DIR := $(BUILD_DIR)/src
OUT_DIR := out
ROOTFS_TEMPLATE := rootfs
OVERLAY_DIR := overlays
INIT_FILE := initramfs/init
KERNEL_HEADERS_DIR := $(BUILD_DIR)/kernel-headers
ROOTFS_IMAGE_SIZE_MB ?= 256
ROOTFS_LABEL ?= ASOXROOT
LEGACY_ROOTFS_DIR := $(BUILD_DIR)/legacy-rootfs
LEGACY_ROOTFS_STAMP := $(LEGACY_ROOTFS_DIR)/.stamp
INITRAMFS_ROOTFS_DIR := $(BUILD_DIR)/initramfs-rootfs
INITRAMFS_ROOTFS_STAMP := $(INITRAMFS_ROOTFS_DIR)/.stamp
MANIFEST_DIR := manifests
POST_MANIFEST_DIR := manifests-post
DEBIAN_CONFIG_DIR := configs/debian
DEBIAN_SOURCES_LIST := $(DEBIAN_CONFIG_DIR)/sources.list
DEB_CACHE_DIR := $(DL_DIR)/debian/$(DEBIAN_SUITE)/$(DEBIAN_ARCH)/packages
TOOLCHAIN_DIR := $(BUILD_DIR)/toolchain
TOOLCHAIN_SOURCES_DIR := $(TOOLCHAIN_DIR)/sources
TOOLCHAIN_BUILD_DIR := $(TOOLCHAIN_DIR)/build
TOOLCHAIN_TOOLS_DIR := $(TOOLCHAIN_DIR)/tools
TOOLCHAIN_SYSROOT := $(TOOLCHAIN_DIR)/sysroot
TOOLCHAIN_TARGET ?= x86_64-amazonspiceox-linux-musl
TOOLCHAIN_SYSROOT_STAMP := $(TOOLCHAIN_SYSROOT)/.headers-stamp
BINUTILS_BUILD_STAMP := $(TOOLCHAIN_TOOLS_DIR)/.binutils-$(BINUTILS_VERSION)-stamp
BINUTILS_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.binutils-$(BINUTILS_VERSION)-extract-stamp
GCC_STAGE1_STAMP := $(TOOLCHAIN_TOOLS_DIR)/.gcc-stage1-$(GCC_VERSION)-stamp
GCC_STAGE2_STAMP := $(TOOLCHAIN_TOOLS_DIR)/.gcc-stage2-$(GCC_VERSION)-stamp
GCC_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.gcc-$(GCC_VERSION)-extract-stamp
MUSL_BUILD_STAMP := $(TOOLCHAIN_SYSROOT)/.musl-$(MUSL_VERSION)-stamp
MUSL_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.musl-$(MUSL_VERSION)-extract-stamp
ZLIB_BUILD_STAMP := $(TOOLCHAIN_SYSROOT)/.zlib-$(ZLIB_VERSION)-stamp
ZLIB_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.zlib-$(ZLIB_VERSION)-extract-stamp
OPENSSL_BUILD_STAMP := $(TOOLCHAIN_SYSROOT)/.openssl-$(OPENSSL_VERSION)-stamp
OPENSSL_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.openssl-$(OPENSSL_VERSION)-extract-stamp

LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BINUTILS_TARBALL := binutils-$(BINUTILS_VERSION).tar.xz
GCC_TARBALL := gcc-$(GCC_VERSION).tar.xz
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
ZLIB_TARBALL := zlib-$(ZLIB_VERSION).tar.gz
OPENSSL_TARBALL := openssl-$(OPENSSL_VERSION).tar.gz
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BINUTILS_URL := https://ftp.gnu.org/gnu/binutils/$(BINUTILS_TARBALL)
GCC_URL := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_TARBALL)
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)
ZLIB_URL := https://zlib.net/$(ZLIB_TARBALL)
OPENSSL_URL := https://openssl-library.org/source/$(OPENSSL_TARBALL)
OPENSSL_MIRROR_URL := https://mirror.openssl-library.org/source/$(OPENSSL_TARBALL)
OPENSSL_GITHUB_URL := https://github.com/openssl/openssl/releases/download/openssl-$(OPENSSL_VERSION)/$(OPENSSL_TARBALL)

KERNEL_SRC := $(SRC_DIR)/linux-$(LINUX_VERSION)
BUSYBOX_SRC := $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
BINUTILS_SRC := $(TOOLCHAIN_SOURCES_DIR)/binutils-current
BINUTILS_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)
GCC_SRC := $(TOOLCHAIN_SOURCES_DIR)/gcc-current
GCC_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-stage1
GCC_STAGE2_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-stage2
MUSL_SRC := $(TOOLCHAIN_SOURCES_DIR)/musl-current
MUSL_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/musl-$(MUSL_VERSION)
ZLIB_SRC := $(TOOLCHAIN_SOURCES_DIR)/zlib-current
ZLIB_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/zlib-$(ZLIB_VERSION)
OPENSSL_SRC := $(TOOLCHAIN_SOURCES_DIR)/openssl-current
OPENSSL_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/openssl-$(OPENSSL_VERSION)
KERNEL_CONFIG_FRAGMENT := configs/kernel/phase3-x86_64.config
KERNEL_EXTRACT_STAMP := $(KERNEL_SRC)/.extract-stamp
BUSYBOX_EXTRACT_STAMP := $(BUSYBOX_SRC)/.extract-stamp
NORMALIZED_PROFILES := base $(filter-out base,$(strip $(ASOX_PROFILES)))
ACTIVE_PROFILE_ID := $(subst $(space),-,$(strip $(NORMALIZED_PROFILES)))
ACTIVE_PROFILE_NAME := $(subst $(space),+,$(strip $(NORMALIZED_PROFILES)))
ROOTFS_DIR := $(BUILD_DIR)/rootfs-$(ACTIVE_PROFILE_ID)
ROOTFS_IMAGE := $(OUT_DIR)/rootfs-$(ACTIVE_PROFILE_ID).ext4
ROOTFS_STAMP := $(ROOTFS_DIR)/.stamp
DEB_FETCH_STAMP := $(DL_DIR)/debian/$(DEBIAN_SUITE)/$(DEBIAN_ARCH)/.$(ACTIVE_PROFILE_ID)-fetch-stamp
PROFILE_OVERLAY_DIRS := $(foreach profile,$(filter-out base,$(NORMALIZED_PROFILES)),$(OVERLAY_DIR)/$(profile))
ROOTFS_OVERLAY_DIRS := $(ROOTFS_TEMPLATE) $(PROFILE_OVERLAY_DIRS)
ROOTFS_OVERLAY_DIRS_COLON := $(subst $(space),:,$(strip $(ROOTFS_OVERLAY_DIRS)))
ROOTFS_FILES := $(shell find $(ROOTFS_TEMPLATE) $(OVERLAY_DIR) -type f 2>/dev/null)

KERNEL_IMAGE := $(OUT_DIR)/bzImage
INITRAMFS := $(OUT_DIR)/rootfs.cpio.gz
BZIMAGE := $(KERNEL_SRC)/arch/x86/boot/bzImage
TOOLCHAIN_HELLO_BIN := $(OUT_DIR)/toolchain-hello
TOOLCHAIN_HELLO_ROOTFS := $(ROOTFS_DIR)/usr/local/bin/hello-toolchain
ZLIB_SMOKE_BIN := $(OUT_DIR)/zlib-smoke
ZLIB_SMOKE_ROOTFS := $(ROOTFS_DIR)/usr/local/bin/zlib-smoke
OPENSSL_SMOKE_BIN := $(OUT_DIR)/openssl-smoke
OPENSSL_SMOKE_ROOTFS := $(ROOTFS_DIR)/usr/local/bin/openssl-smoke
ALL_MANIFESTS := $(wildcard $(MANIFEST_DIR)/*.txt)
ALL_POST_MANIFESTS := $(wildcard $(POST_MANIFEST_DIR)/*.txt)
DEBIAN_MANIFESTS ?= $(foreach profile,$(NORMALIZED_PROFILES),$(MANIFEST_DIR)/$(profile).txt)
DEBIAN_POST_MANIFESTS ?= $(foreach profile,$(NORMALIZED_PROFILES),$(wildcard $(POST_MANIFEST_DIR)/$(profile).txt))
QEMU_SMOKE_LOG := $(OUT_DIR)/qemu-smoke-$(ACTIVE_PROFILE_ID).log
QEMU_NET_SMOKE_LOG := $(OUT_DIR)/qemu-smoke-net-$(ACTIVE_PROFILE_ID).log
QEMU_AWSCLI_SMOKE_LOG := $(OUT_DIR)/qemu-smoke-awscli-$(ACTIVE_PROFILE_ID).log
QEMU_APT_SMOKE_LOG := $(OUT_DIR)/qemu-smoke-apt-$(ACTIVE_PROFILE_ID).log

JOBS ?= $(shell nproc 2>/dev/null || echo 2)
DETECTED_BUSYBOX_CC := $(shell command -v musl-gcc >/dev/null 2>&1 && echo musl-gcc || echo gcc)
BUSYBOX_CC ?= $(DETECTED_BUSYBOX_CC)
BUSYBOX_CC := $(if $(strip $(BUSYBOX_CC)),$(BUSYBOX_CC),$(DETECTED_BUSYBOX_CC))
QEMU_MEMORY ?= 512M
QEMU_APPEND ?= console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw
SMOKE_TIMEOUT ?= 30s
APT_SMOKE_TIMEOUT ?= 180s

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "AmazonSpiceOx"
	@echo ""
	@echo "Targets:"
	@echo "  make deps       Check host tools"
	@echo "  make all        Build kernel, Debian-based rootfs, initramfs, and ext4 image (rootfs/image may need sudo)"
	@echo "  make profile-info Show active profile, manifests, overlays, and output paths"
	@echo "  make fetch      Download Debian packages from the configured public mirror"
	@echo "  make verify-packages Validate cached Debian package archives"
	@echo "  make rootfs     Build the generated root filesystem from Debian packages and overlays (requires sudo)"
	@echo "  make image      Build the ext4 persistent root filesystem image"
	@echo "  make legacy-rootfs Build the older BusyBox-compiled rootfs flow for reference"
	@echo "  make toolchain-sysroot  Export kernel headers into the Phase IV sysroot"
	@echo "  make binutils   Build cross-binutils for $(TOOLCHAIN_TARGET)"
	@echo "  make gcc-stage1 Build the stage-1 cross C compiler and libgcc"
	@echo "  make gcc-stage2 Rebuild GCC against musl in the sysroot"
	@echo "  make musl       Install musl into the Phase IV sysroot"
	@echo "  make zlib       Build the first real package into the Phase IV sysroot"
	@echo "  make openssl    Build OpenSSL into the Phase IV sysroot"
	@echo "  make toolchain  Bootstrap the Phase IV toolchain through GCC stage 2"
	@echo "  make toolchain-hello       Build a static hello-world with the cross-toolchain"
	@echo "  make toolchain-hello-rootfs Copy the hello-world into the active profile rootfs and rebuild the disk image"
	@echo "  make zlib-smoke            Build a static zlib-linked smoke binary"
	@echo "  make zlib-smoke-rootfs     Copy the zlib smoke binary into the active profile rootfs and rebuild the disk image"
	@echo "  make openssl-smoke         Build a static OpenSSL-linked smoke binary"
	@echo "  make openssl-smoke-rootfs  Copy the OpenSSL smoke binary into the active profile rootfs and rebuild the disk image"
	@echo "  make initramfs  Package the generated rootfs as initramfs"
	@echo "  make root-disk  Build the ext4 persistent root filesystem image"
	@echo "  make run        Boot in QEMU"
	@echo "  make run-only   Boot the current artifacts in QEMU without rebuilding"
	@echo "  make smoke      Boot briefly and check AMAZONSPICEOX_PHASE3_BOOT_OK"
	@echo "  make smoke-net  Boot briefly, validate basic guest networking, and check AMAZONSPICEOX_NETWORK_SMOKE_OK"
	@echo "  make smoke-awscli Boot briefly, validate guest awscli, and check AMAZONSPICEOX_AWSCLI_SMOKE_OK"
	@echo "  make smoke-apt  Boot briefly, run apt validation inside the guest, and check AMAZONSPICEOX_APT_SMOKE_OK"
	@echo "  make smoke-only      Run the boot smoke against existing artifacts only"
	@echo "  make smoke-net-only  Run the guest network smoke against existing artifacts only"
	@echo "  make smoke-awscli-only Run the guest awscli smoke against existing artifacts only"
	@echo "  make smoke-apt-only  Run the apt smoke against existing artifacts only"
	@echo "  make clean      Remove generated build/output files"
	@echo "  make distclean  Also remove downloaded tarballs"
	@echo ""
	@echo "Profile selection:"
	@echo "  make fetch ASOX_PROFILES=\"base debug\""
	@echo "  sudo -E make rootfs ASOX_PROFILES=\"base aws\""

.PHONY: profile-info
profile-info:
	@echo "Active profiles: $(NORMALIZED_PROFILES)"
	@echo "Profile name: $(ACTIVE_PROFILE_NAME)"
	@echo "Manifests: $(DEBIAN_MANIFESTS)"
	@echo "Post manifests: $(DEBIAN_POST_MANIFESTS)"
	@echo "Overlays: $(ROOTFS_OVERLAY_DIRS)"
	@echo "Rootfs dir: $(ROOTFS_DIR)"
	@echo "Rootfs image: $(ROOTFS_IMAGE)"

.PHONY: deps
deps:
	sh scripts/check-tools.sh

.PHONY: check-build-path
check-build-path:
	sh scripts/check-build-path.sh

.PHONY: all
all: check-build-path $(KERNEL_IMAGE) $(INITRAMFS) $(ROOTFS_IMAGE)

$(DL_DIR) $(SRC_DIR) $(OUT_DIR) $(TOOLCHAIN_SOURCES_DIR) $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_TOOLS_DIR) $(TOOLCHAIN_SYSROOT):
	mkdir -p $@

$(DL_DIR)/$(LINUX_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(LINUX_URL)

$(DL_DIR)/$(BUSYBOX_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(BUSYBOX_URL)

$(DL_DIR)/$(BINUTILS_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(BINUTILS_URL)

$(DL_DIR)/$(GCC_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(GCC_URL)

$(DL_DIR)/$(MUSL_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(MUSL_URL)

$(DL_DIR)/$(ZLIB_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(ZLIB_URL)

$(DL_DIR)/$(OPENSSL_TARBALL): scripts/download-openssl.sh | $(DL_DIR)
	sh scripts/download-openssl.sh "$@" "$(OPENSSL_URL)" "$(OPENSSL_MIRROR_URL)" "$(OPENSSL_GITHUB_URL)"

$(KERNEL_EXTRACT_STAMP): $(DL_DIR)/$(LINUX_TARBALL) scripts/extract-source.sh | $(SRC_DIR)
	sh scripts/extract-source.sh "$(SRC_DIR)" "$<"
	touch "$@"

$(BUSYBOX_EXTRACT_STAMP): $(DL_DIR)/$(BUSYBOX_TARBALL) scripts/extract-source.sh | $(SRC_DIR)
	sh scripts/extract-source.sh "$(SRC_DIR)" "$<"
	touch "$@"

$(BINUTILS_EXTRACT_STAMP): $(DL_DIR)/$(BINUTILS_TARBALL) | $(TOOLCHAIN_SOURCES_DIR)
	@set -eu; \
	topdir=$$(tar -tf "$<" | head -1 | cut -d/ -f1); \
	rm -rf "$(TOOLCHAIN_SOURCES_DIR)/$$topdir" "$(BINUTILS_SRC)"; \
	tar -C "$(TOOLCHAIN_SOURCES_DIR)" -xf "$<"; \
	ln -s "$$topdir" "$(BINUTILS_SRC)"; \
	touch "$@"

$(GCC_EXTRACT_STAMP): $(DL_DIR)/$(GCC_TARBALL) | $(TOOLCHAIN_SOURCES_DIR)
	@set -eu; \
	topdir=$$(tar -tf "$<" | head -1 | cut -d/ -f1); \
	rm -rf "$(TOOLCHAIN_SOURCES_DIR)/$$topdir" "$(GCC_SRC)"; \
	tar -C "$(TOOLCHAIN_SOURCES_DIR)" -xf "$<"; \
	ln -s "$$topdir" "$(GCC_SRC)"; \
	touch "$@"

$(MUSL_EXTRACT_STAMP): $(DL_DIR)/$(MUSL_TARBALL) | $(TOOLCHAIN_SOURCES_DIR)
	@set -eu; \
	topdir=$$(tar -tf "$<" | head -1 | cut -d/ -f1); \
	rm -rf "$(TOOLCHAIN_SOURCES_DIR)/$$topdir" "$(MUSL_SRC)"; \
	tar -C "$(TOOLCHAIN_SOURCES_DIR)" -xf "$<"; \
	ln -s "$$topdir" "$(MUSL_SRC)"; \
	touch "$@"

$(ZLIB_EXTRACT_STAMP): $(DL_DIR)/$(ZLIB_TARBALL) | $(TOOLCHAIN_SOURCES_DIR)
	@set -eu; \
	topdir=$$(tar -tf "$<" | head -1 | cut -d/ -f1); \
	rm -rf "$(TOOLCHAIN_SOURCES_DIR)/$$topdir" "$(ZLIB_SRC)"; \
	tar -C "$(TOOLCHAIN_SOURCES_DIR)" -xf "$<"; \
	ln -s "$$topdir" "$(ZLIB_SRC)"; \
	touch "$@"

$(OPENSSL_EXTRACT_STAMP): $(DL_DIR)/$(OPENSSL_TARBALL) | $(TOOLCHAIN_SOURCES_DIR)
	@set -eu; \
	topdir=$$(tar -tf "$<" | head -1 | cut -d/ -f1); \
	rm -rf "$(TOOLCHAIN_SOURCES_DIR)/$$topdir" "$(OPENSSL_SRC)"; \
	tar -C "$(TOOLCHAIN_SOURCES_DIR)" -xf "$<"; \
	ln -s "$$topdir" "$(OPENSSL_SRC)"; \
	touch "$@"

$(KERNEL_SRC)/.config: $(KERNEL_EXTRACT_STAMP) $(KERNEL_CONFIG_FRAGMENT)
	$(MAKE) -C $(KERNEL_SRC) ARCH=$(KERNEL_ARCH) $(KERNEL_DEFCONFIG)
	sh $(KERNEL_SRC)/scripts/kconfig/merge_config.sh -m -O $(KERNEL_SRC) $(KERNEL_SRC)/.config $(KERNEL_CONFIG_FRAGMENT)
	$(MAKE) -C $(KERNEL_SRC) ARCH=$(KERNEL_ARCH) olddefconfig

$(BZIMAGE): $(KERNEL_SRC)/.config
	$(MAKE) -C $(KERNEL_SRC) ARCH=$(KERNEL_ARCH) -j$(JOBS) bzImage

$(KERNEL_IMAGE): $(BZIMAGE) | $(OUT_DIR)
	cp $< $@

.PHONY: kernel-headers
kernel-headers: $(KERNEL_HEADERS_DIR)/include/linux/types.h

$(KERNEL_HEADERS_DIR)/include/linux/types.h: $(KERNEL_SRC)/.config
	rm -rf $(KERNEL_HEADERS_DIR)
	$(MAKE) -C $(KERNEL_SRC) ARCH=$(KERNEL_ARCH) INSTALL_HDR_PATH="$(abspath $(KERNEL_HEADERS_DIR))" headers_install

.PHONY: toolchain-sysroot
toolchain-sysroot: $(TOOLCHAIN_SYSROOT_STAMP)

$(TOOLCHAIN_SYSROOT_STAMP): $(KERNEL_SRC)/.config scripts/build-toolchain-sysroot.sh | $(TOOLCHAIN_SYSROOT)
	sh scripts/build-toolchain-sysroot.sh "$(KERNEL_SRC)" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(KERNEL_ARCH)"
	touch "$@"

.PHONY: binutils
binutils: $(BINUTILS_BUILD_STAMP)

$(BINUTILS_BUILD_STAMP): $(BINUTILS_EXTRACT_STAMP) $(TOOLCHAIN_SYSROOT_STAMP) scripts/build-binutils.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_TOOLS_DIR)
	sh scripts/build-binutils.sh "$(BINUTILS_SRC)" "$(BINUTILS_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: gcc-stage1
gcc-stage1: $(GCC_STAGE1_STAMP)

$(GCC_STAGE1_STAMP): $(GCC_EXTRACT_STAMP) $(BINUTILS_BUILD_STAMP) $(TOOLCHAIN_SYSROOT_STAMP) scripts/build-gcc-stage1.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_TOOLS_DIR)
	sh scripts/build-gcc-stage1.sh "$(GCC_SRC)" "$(GCC_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: musl
musl: $(MUSL_BUILD_STAMP)

$(MUSL_BUILD_STAMP): $(MUSL_EXTRACT_STAMP) $(GCC_STAGE1_STAMP) $(TOOLCHAIN_SYSROOT_STAMP) scripts/build-musl.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_SYSROOT)
	sh scripts/build-musl.sh "$(MUSL_SRC)" "$(MUSL_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: gcc-stage2
gcc-stage2: $(GCC_STAGE2_STAMP)

$(GCC_STAGE2_STAMP): $(GCC_EXTRACT_STAMP) $(MUSL_BUILD_STAMP) scripts/build-gcc-stage2.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_TOOLS_DIR)
	sh scripts/build-gcc-stage2.sh "$(GCC_SRC)" "$(GCC_STAGE2_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: zlib
zlib: $(ZLIB_BUILD_STAMP)

$(ZLIB_BUILD_STAMP): $(ZLIB_EXTRACT_STAMP) $(GCC_STAGE2_STAMP) scripts/build-zlib.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_SYSROOT)
	sh scripts/build-zlib.sh "$(ZLIB_SRC)" "$(ZLIB_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: openssl
openssl: $(OPENSSL_BUILD_STAMP)

$(OPENSSL_BUILD_STAMP): $(OPENSSL_EXTRACT_STAMP) $(GCC_STAGE2_STAMP) scripts/build-openssl.sh | $(TOOLCHAIN_BUILD_DIR) $(TOOLCHAIN_SYSROOT)
	sh scripts/build-openssl.sh "$(OPENSSL_SRC)" "$(OPENSSL_BUILD_DIR)" "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$(JOBS)"
	touch "$@"

.PHONY: toolchain
toolchain: toolchain-sysroot binutils gcc-stage1 musl gcc-stage2

.PHONY: toolchain-hello
toolchain-hello: $(TOOLCHAIN_HELLO_BIN)

$(TOOLCHAIN_HELLO_BIN): $(GCC_STAGE2_STAMP) scripts/build-toolchain-hello.sh | $(OUT_DIR)
	sh scripts/build-toolchain-hello.sh "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$@"

.PHONY: toolchain-hello-rootfs
toolchain-hello-rootfs: $(ROOTFS_STAMP) $(TOOLCHAIN_HELLO_BIN) scripts/build-root-disk.sh
	mkdir -p "$(dir $(TOOLCHAIN_HELLO_ROOTFS))"
	install -m 0755 "$(TOOLCHAIN_HELLO_BIN)" "$(TOOLCHAIN_HELLO_ROOTFS)"
	sh scripts/build-root-disk.sh "$(ROOTFS_DIR)" "$(ROOTFS_IMAGE)" "$(ROOTFS_IMAGE_SIZE_MB)" "$(ROOTFS_LABEL)"

.PHONY: zlib-smoke
zlib-smoke: $(ZLIB_SMOKE_BIN)

$(ZLIB_SMOKE_BIN): $(ZLIB_BUILD_STAMP) scripts/build-zlib-smoke.sh | $(OUT_DIR)
	sh scripts/build-zlib-smoke.sh "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$@"

.PHONY: zlib-smoke-rootfs
zlib-smoke-rootfs: $(ROOTFS_STAMP) $(ZLIB_SMOKE_BIN) scripts/build-root-disk.sh
	mkdir -p "$(dir $(ZLIB_SMOKE_ROOTFS))"
	install -m 0755 "$(ZLIB_SMOKE_BIN)" "$(ZLIB_SMOKE_ROOTFS)"
	sh scripts/build-root-disk.sh "$(ROOTFS_DIR)" "$(ROOTFS_IMAGE)" "$(ROOTFS_IMAGE_SIZE_MB)" "$(ROOTFS_LABEL)"

.PHONY: openssl-smoke
openssl-smoke: $(OPENSSL_SMOKE_BIN)

$(OPENSSL_SMOKE_BIN): $(OPENSSL_BUILD_STAMP) scripts/build-openssl-smoke.sh | $(OUT_DIR)
	sh scripts/build-openssl-smoke.sh "$(abspath $(TOOLCHAIN_TOOLS_DIR))" "$(abspath $(TOOLCHAIN_SYSROOT))" "$(TOOLCHAIN_TARGET)" "$@"

.PHONY: openssl-smoke-rootfs
openssl-smoke-rootfs: $(ROOTFS_STAMP) $(OPENSSL_SMOKE_BIN) scripts/build-root-disk.sh
	mkdir -p "$(dir $(OPENSSL_SMOKE_ROOTFS))"
	install -m 0755 "$(OPENSSL_SMOKE_BIN)" "$(OPENSSL_SMOKE_ROOTFS)"
	sh scripts/build-root-disk.sh "$(ROOTFS_DIR)" "$(ROOTFS_IMAGE)" "$(ROOTFS_IMAGE_SIZE_MB)" "$(ROOTFS_LABEL)"

.PHONY: fetch
fetch: check-build-path $(DEB_FETCH_STAMP)

$(DEB_FETCH_STAMP): $(DEBIAN_SOURCES_LIST) $(ALL_MANIFESTS) scripts/fetch-packages.sh | $(DL_DIR)
	sh scripts/fetch-packages.sh "$(DEBIAN_SUITE)" "$(DEBIAN_ARCH)" "$(DEBIAN_MIRROR)" "$(abspath $(DEB_CACHE_DIR))" $(DEBIAN_MANIFESTS)
	touch "$@"

.PHONY: verify-packages
verify-packages: $(DEB_FETCH_STAMP)
	sh scripts/verify-packages.sh "$(abspath $(DEB_CACHE_DIR))"

$(BUSYBOX_SRC)/.config: $(BUSYBOX_EXTRACT_STAMP) Makefile scripts/kconfig-set.sh
	$(MAKE) -C $(BUSYBOX_SRC) allnoconfig
	sh scripts/kconfig-set.sh $(BUSYBOX_SRC)/.config \
		CAT=y \
		CHMOD=y \
		CLEAR=y \
		CTTYHACK=y \
		CUT=y \
		DMESG=y \
		ECHO=y \
		ENV=y \
		FALSE=y \
		GREP=y \
		HOSTNAME=y \
		IFCONFIG=y \
		INSTALL_APPLET_SYMLINKS=y \
		IP=y \
		FEATURE_IP_ADDRESS=y \
		FEATURE_IP_LINK=y \
		FEATURE_IP_ROUTE=y \
		LS=y \
		MKDIR=y \
		MKNOD=y \
		MOUNT=y \
		FEATURE_MOUNT_FLAGS=y \
		MV=y \
		PING=y \
		PS=y \
		PRINTF=y \
		PWD=y \
		ROUTE=y \
		SED=y \
		SETSID=y \
		SLEEP=y \
		SWITCH_ROOT=y \
		SYNC=y \
		STATIC=y \
		ASH=y \
		SH_IS_ASH=y \
		FEATURE_SH_STANDALONE=y \
		FEATURE_PREFER_APPLETS=y \
		TEST=y \
		TEST1=y \
		TEE=y \
		TRUE=y \
		UMOUNT=y \
		UNAME=y \
		UDHCPC=y
	yes "" | $(MAKE) -C $(BUSYBOX_SRC) oldconfig

.PHONY: legacy-rootfs
legacy-rootfs: check-build-path $(LEGACY_ROOTFS_STAMP)

$(LEGACY_ROOTFS_STAMP): $(BUSYBOX_SRC)/.config $(KERNEL_HEADERS_DIR)/include/linux/types.h $(INIT_FILE) $(ROOTFS_FILES) scripts/build-rootfs-legacy.sh
	sh scripts/build-rootfs-legacy.sh "$(BUSYBOX_SRC)" "$(ROOTFS_TEMPLATE)" "$(INIT_FILE)" "$(abspath $(LEGACY_ROOTFS_DIR))" "$(BUSYBOX_CC)" "$(JOBS)" "$(abspath $(KERNEL_HEADERS_DIR))"
	touch "$@"

.PHONY: rootfs
rootfs: check-build-path $(ROOTFS_STAMP)

$(ROOTFS_STAMP): $(DEB_FETCH_STAMP) $(INIT_FILE) $(ROOTFS_FILES) $(DEBIAN_SOURCES_LIST) $(ALL_POST_MANIFESTS) scripts/build-rootfs.sh
	DEBIAN_POST_MANIFESTS="$(DEBIAN_POST_MANIFESTS)" sh scripts/build-rootfs.sh "$(DEBIAN_SUITE)" "$(DEBIAN_ARCH)" "$(DEBIAN_MIRROR)" "$(DEBIAN_SOURCES_LIST)" "$(ROOTFS_OVERLAY_DIRS_COLON)" "$(INIT_FILE)" "$(abspath $(ROOTFS_DIR))" "$(abspath $(DEB_CACHE_DIR))" "$(ACTIVE_PROFILE_NAME)" $(DEBIAN_MANIFESTS)
	touch "$@"

$(INITRAMFS_ROOTFS_STAMP): $(BUSYBOX_SRC)/.config $(KERNEL_HEADERS_DIR)/include/linux/types.h $(INIT_FILE) $(ROOTFS_FILES) scripts/build-rootfs-legacy.sh
	sh scripts/build-rootfs-legacy.sh "$(BUSYBOX_SRC)" "$(ROOTFS_TEMPLATE)" "$(INIT_FILE)" "$(abspath $(INITRAMFS_ROOTFS_DIR))" "$(BUSYBOX_CC)" "$(JOBS)" "$(abspath $(KERNEL_HEADERS_DIR))"
	touch "$@"

.PHONY: initramfs
initramfs: check-build-path $(INITRAMFS)

$(INITRAMFS): $(INITRAMFS_ROOTFS_STAMP) scripts/build-initramfs.sh | $(OUT_DIR)
	sh scripts/build-initramfs.sh "$(INITRAMFS_ROOTFS_DIR)" "$@"

.PHONY: root-disk
root-disk: check-build-path $(ROOTFS_IMAGE)

.PHONY: image
image: root-disk

$(ROOTFS_IMAGE): $(ROOTFS_STAMP) scripts/build-root-disk.sh | $(OUT_DIR)
	sh scripts/build-root-disk.sh "$(ROOTFS_DIR)" "$@" "$(ROOTFS_IMAGE_SIZE_MB)" "$(ROOTFS_LABEL)"

.PHONY: run
run: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: run-only
run-only: check-build-path
	@test -f "$(KERNEL_IMAGE)" || { echo "missing artifact: $(KERNEL_IMAGE)"; exit 1; }
	@test -f "$(INITRAMFS)" || { echo "missing artifact: $(INITRAMFS)"; exit 1; }
	@test -f "$(ROOTFS_IMAGE)" || { echo "missing artifact: $(ROOTFS_IMAGE)"; exit 1; }
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke
smoke: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh boot "$(SMOKE_TIMEOUT)" "AMAZONSPICEOX_PHASE3_BOOT_OK" "$(QEMU_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-net
smoke-net: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh network "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_NETWORK_SMOKE_OK" "$(QEMU_NET_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-awscli
smoke-awscli: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh awscli "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_AWSCLI_SMOKE_OK" "$(QEMU_AWSCLI_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-apt
smoke-apt: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh apt "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_APT_SMOKE_OK" "$(QEMU_APT_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-only
smoke-only: check-build-path
	@test -f "$(KERNEL_IMAGE)" || { echo "missing artifact: $(KERNEL_IMAGE)"; exit 1; }
	@test -f "$(INITRAMFS)" || { echo "missing artifact: $(INITRAMFS)"; exit 1; }
	@test -f "$(ROOTFS_IMAGE)" || { echo "missing artifact: $(ROOTFS_IMAGE)"; exit 1; }
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh boot "$(SMOKE_TIMEOUT)" "AMAZONSPICEOX_PHASE3_BOOT_OK" "$(QEMU_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-net-only
smoke-net-only: check-build-path
	@test -f "$(KERNEL_IMAGE)" || { echo "missing artifact: $(KERNEL_IMAGE)"; exit 1; }
	@test -f "$(INITRAMFS)" || { echo "missing artifact: $(INITRAMFS)"; exit 1; }
	@test -f "$(ROOTFS_IMAGE)" || { echo "missing artifact: $(ROOTFS_IMAGE)"; exit 1; }
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh network "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_NETWORK_SMOKE_OK" "$(QEMU_NET_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-awscli-only
smoke-awscli-only: check-build-path
	@test -f "$(KERNEL_IMAGE)" || { echo "missing artifact: $(KERNEL_IMAGE)"; exit 1; }
	@test -f "$(INITRAMFS)" || { echo "missing artifact: $(INITRAMFS)"; exit 1; }
	@test -f "$(ROOTFS_IMAGE)" || { echo "missing artifact: $(ROOTFS_IMAGE)"; exit 1; }
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh awscli "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_AWSCLI_SMOKE_OK" "$(QEMU_AWSCLI_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke-apt-only
smoke-apt-only: check-build-path
	@test -f "$(KERNEL_IMAGE)" || { echo "missing artifact: $(KERNEL_IMAGE)"; exit 1; }
	@test -f "$(INITRAMFS)" || { echo "missing artifact: $(INITRAMFS)"; exit 1; }
	@test -f "$(ROOTFS_IMAGE)" || { echo "missing artifact: $(ROOTFS_IMAGE)"; exit 1; }
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-smoke.sh apt "$(APT_SMOKE_TIMEOUT)" "AMAZONSPICEOX_APT_SMOKE_OK" "$(QEMU_APT_SMOKE_LOG)" "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: docker-build docker-shell docker-run
docker-build:
	docker build -t $(PROJECT)-builder .

docker-shell:
	docker run --rm -it -v "$(CURDIR):/work" $(PROJECT)-builder bash

docker-run:
	docker run --rm -it -v "$(CURDIR):/work" $(PROJECT)-builder make run

.PHONY: clean distclean
clean:
	rm -rf $(BUILD_DIR) $(OUT_DIR)

distclean: clean
	rm -rf $(DL_DIR)
