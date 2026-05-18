PROJECT := amazonspiceox

KERNEL_ARCH ?= x86
KERNEL_DEFCONFIG ?= x86_64_defconfig
LINUX_VERSION ?= 6.6.1
BUSYBOX_VERSION ?= 1.36.1
BINUTILS_VERSION ?= 2.46.0
GCC_VERSION ?= 14.3.0
MUSL_VERSION ?= 1.2.5

BUILD_DIR := build
DL_DIR := downloads
SRC_DIR := $(BUILD_DIR)/src
ROOTFS_DIR := $(BUILD_DIR)/rootfs
OUT_DIR := out
ROOTFS_TEMPLATE := rootfs
INIT_FILE := initramfs/init
KERNEL_HEADERS_DIR := $(BUILD_DIR)/kernel-headers
ROOTFS_IMAGE := $(OUT_DIR)/rootfs.ext4
ROOTFS_IMAGE_SIZE_MB ?= 256
ROOTFS_LABEL ?= ASOXROOT
ROOTFS_STAMP := $(ROOTFS_DIR)/.stamp
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
GCC_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.gcc-$(GCC_VERSION)-extract-stamp
MUSL_BUILD_STAMP := $(TOOLCHAIN_SYSROOT)/.musl-$(MUSL_VERSION)-stamp
MUSL_EXTRACT_STAMP := $(TOOLCHAIN_SOURCES_DIR)/.musl-$(MUSL_VERSION)-extract-stamp

LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
BINUTILS_TARBALL := binutils-$(BINUTILS_VERSION).tar.xz
GCC_TARBALL := gcc-$(GCC_VERSION).tar.xz
MUSL_TARBALL := musl-$(MUSL_VERSION).tar.gz
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)
BINUTILS_URL := https://ftp.gnu.org/gnu/binutils/$(BINUTILS_TARBALL)
GCC_URL := https://ftp.gnu.org/gnu/gcc/gcc-$(GCC_VERSION)/$(GCC_TARBALL)
MUSL_URL := https://musl.libc.org/releases/$(MUSL_TARBALL)

KERNEL_SRC := $(SRC_DIR)/linux-$(LINUX_VERSION)
BUSYBOX_SRC := $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
BINUTILS_SRC := $(TOOLCHAIN_SOURCES_DIR)/binutils-current
BINUTILS_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/binutils-$(BINUTILS_VERSION)
GCC_SRC := $(TOOLCHAIN_SOURCES_DIR)/gcc-current
GCC_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/gcc-$(GCC_VERSION)-stage1
MUSL_SRC := $(TOOLCHAIN_SOURCES_DIR)/musl-current
MUSL_BUILD_DIR := $(TOOLCHAIN_BUILD_DIR)/musl-$(MUSL_VERSION)
KERNEL_CONFIG_FRAGMENT := configs/kernel/phase3-x86_64.config
ROOTFS_FILES := $(shell find $(ROOTFS_TEMPLATE) -type f 2>/dev/null)

KERNEL_IMAGE := $(OUT_DIR)/bzImage
INITRAMFS := $(OUT_DIR)/rootfs.cpio.gz
BZIMAGE := $(KERNEL_SRC)/arch/x86/boot/bzImage

JOBS ?= $(shell nproc 2>/dev/null || echo 2)
DETECTED_BUSYBOX_CC := $(shell command -v musl-gcc >/dev/null 2>&1 && echo musl-gcc || echo gcc)
BUSYBOX_CC ?= $(DETECTED_BUSYBOX_CC)
BUSYBOX_CC := $(if $(strip $(BUSYBOX_CC)),$(BUSYBOX_CC),$(DETECTED_BUSYBOX_CC))
QEMU_MEMORY ?= 512M
QEMU_APPEND ?= console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init root=/dev/vda rootfstype=ext4 rw
SMOKE_TIMEOUT ?= 30s

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "AmazonSpiceOx"
	@echo ""
	@echo "Targets:"
	@echo "  make deps       Check host tools"
	@echo "  make all        Build kernel, initramfs, and persistent root disk"
	@echo "  make toolchain-sysroot  Export kernel headers into the Phase IV sysroot"
	@echo "  make binutils   Build cross-binutils for $(TOOLCHAIN_TARGET)"
	@echo "  make gcc-stage1 Build the stage-1 cross C compiler and libgcc"
	@echo "  make musl       Install musl into the Phase IV sysroot"
	@echo "  make toolchain  Bootstrap the Phase IV toolchain foundation"
	@echo "  make rootfs     Build the generated root filesystem"
	@echo "  make initramfs  Package the generated rootfs as initramfs"
	@echo "  make root-disk  Build the ext4 persistent root filesystem image"
	@echo "  make run        Boot in QEMU"
	@echo "  make smoke      Boot briefly and check AMAZONSPICEOX_PHASE3_BOOT_OK"
	@echo "  make clean      Remove generated build/rootfs/output files"
	@echo "  make distclean  Also remove downloaded tarballs"

.PHONY: deps
deps:
	sh scripts/check-tools.sh

.PHONY: all
all: $(KERNEL_IMAGE) $(INITRAMFS) $(ROOTFS_IMAGE)

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

$(KERNEL_SRC)/Makefile: $(DL_DIR)/$(LINUX_TARBALL) | $(SRC_DIR)
	tar -C $(SRC_DIR) -xf $<

$(BUSYBOX_SRC)/Makefile: $(DL_DIR)/$(BUSYBOX_TARBALL) | $(SRC_DIR)
	tar -C $(SRC_DIR) -xf $<

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

$(KERNEL_SRC)/.config: $(KERNEL_SRC)/Makefile $(KERNEL_CONFIG_FRAGMENT)
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

.PHONY: toolchain
toolchain: toolchain-sysroot binutils gcc-stage1 musl

$(BUSYBOX_SRC)/.config: $(BUSYBOX_SRC)/Makefile Makefile scripts/kconfig-set.sh
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

.PHONY: rootfs
rootfs: $(ROOTFS_STAMP)

$(ROOTFS_STAMP): $(BUSYBOX_SRC)/.config $(KERNEL_HEADERS_DIR)/include/linux/types.h $(INIT_FILE) $(ROOTFS_FILES) scripts/build-rootfs.sh
	sh scripts/build-rootfs.sh "$(BUSYBOX_SRC)" "$(ROOTFS_TEMPLATE)" "$(INIT_FILE)" "$(abspath $(ROOTFS_DIR))" "$(BUSYBOX_CC)" "$(JOBS)" "$(abspath $(KERNEL_HEADERS_DIR))"
	touch "$@"

.PHONY: initramfs
initramfs: $(INITRAMFS)

$(INITRAMFS): $(ROOTFS_STAMP) scripts/build-initramfs.sh | $(OUT_DIR)
	sh scripts/build-initramfs.sh "$(ROOTFS_DIR)" "$@"

.PHONY: root-disk
root-disk: $(ROOTFS_IMAGE)

$(ROOTFS_IMAGE): $(ROOTFS_STAMP) scripts/build-root-disk.sh | $(OUT_DIR)
	sh scripts/build-root-disk.sh "$(ROOTFS_DIR)" "$@" "$(ROOTFS_IMAGE_SIZE_MB)" "$(ROOTFS_LABEL)"

.PHONY: run
run: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)"

.PHONY: smoke
smoke: all
	@set -eu; \
	status=0; \
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" timeout $(SMOKE_TIMEOUT) sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)" "$(ROOTFS_IMAGE)" > $(OUT_DIR)/qemu-smoke.log 2>&1 || status=$$?; \
	if [ "$$status" != "0" ] && [ "$$status" != "124" ]; then \
		cat $(OUT_DIR)/qemu-smoke.log; \
		exit "$$status"; \
	fi; \
	grep -q "AMAZONSPICEOX_PHASE3_BOOT_OK" $(OUT_DIR)/qemu-smoke.log; \
	echo "Boot marker found in $(OUT_DIR)/qemu-smoke.log"

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
