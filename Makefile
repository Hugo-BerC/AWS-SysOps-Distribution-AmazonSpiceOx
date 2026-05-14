PROJECT := amazonspiceox

KERNEL_ARCH ?= x86
KERNEL_DEFCONFIG ?= x86_64_defconfig
LINUX_VERSION ?= 6.6.1
BUSYBOX_VERSION ?= 1.36.1

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

LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)

KERNEL_SRC := $(SRC_DIR)/linux-$(LINUX_VERSION)
BUSYBOX_SRC := $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
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

$(DL_DIR) $(SRC_DIR) $(OUT_DIR):
	mkdir -p $@

$(DL_DIR)/$(LINUX_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(LINUX_URL)

$(DL_DIR)/$(BUSYBOX_TARBALL): | $(DL_DIR)
	curl --fail --location --output $@ $(BUSYBOX_URL)

$(KERNEL_SRC)/Makefile: $(DL_DIR)/$(LINUX_TARBALL) | $(SRC_DIR)
	tar -C $(SRC_DIR) -xf $<

$(BUSYBOX_SRC)/Makefile: $(DL_DIR)/$(BUSYBOX_TARBALL) | $(SRC_DIR)
	tar -C $(SRC_DIR) -xf $<

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
