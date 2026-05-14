PROJECT := mentat-linux

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

LINUX_TARBALL := linux-$(LINUX_VERSION).tar.xz
BUSYBOX_TARBALL := busybox-$(BUSYBOX_VERSION).tar.bz2
LINUX_URL := https://cdn.kernel.org/pub/linux/kernel/v6.x/$(LINUX_TARBALL)
BUSYBOX_URL := https://busybox.net/downloads/$(BUSYBOX_TARBALL)

KERNEL_SRC := $(SRC_DIR)/linux-$(LINUX_VERSION)
BUSYBOX_SRC := $(SRC_DIR)/busybox-$(BUSYBOX_VERSION)
KERNEL_CONFIG_FRAGMENT := configs/kernel/phase2-x86_64.config

KERNEL_IMAGE := $(OUT_DIR)/bzImage
INITRAMFS := $(OUT_DIR)/rootfs.cpio.gz
BZIMAGE := $(KERNEL_SRC)/arch/x86/boot/bzImage

JOBS ?= $(shell nproc 2>/dev/null || echo 2)
BUSYBOX_CC ?= $(shell command -v musl-gcc >/dev/null 2>&1 && echo musl-gcc || echo gcc)
QEMU_MEMORY ?= 512M
QEMU_APPEND ?= console=ttyS0 earlyprintk=serial,ttyS0,115200 panic=-1 init=/init
SMOKE_TIMEOUT ?= 30s

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "Mentat Linux"
	@echo ""
	@echo "Targets:"
	@echo "  make deps       Check host tools"
	@echo "  make all        Build kernel image and initramfs"
	@echo "  make rootfs     Build the generated root filesystem"
	@echo "  make initramfs  Package the generated rootfs as initramfs"
	@echo "  make run        Boot in QEMU"
	@echo "  make smoke      Boot briefly and check MENTAT_LINUX_PHASE2_BOOT_OK"
	@echo "  make clean      Remove generated build/rootfs/output files"
	@echo "  make distclean  Also remove downloaded tarballs"

.PHONY: deps
deps:
	sh scripts/check-tools.sh

.PHONY: all
all: $(KERNEL_IMAGE) $(INITRAMFS)

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

$(BUSYBOX_SRC)/.config: $(BUSYBOX_SRC)/Makefile
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
		MV=y \
		PING=y \
		PS=y \
		PRINTF=y \
		PWD=y \
		ROUTE=y \
		SED=y \
		SETSID=y \
		SLEEP=y \
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
rootfs: $(BUSYBOX_SRC)/.config $(INIT_FILE) scripts/build-rootfs.sh
	sh scripts/build-rootfs.sh "$(BUSYBOX_SRC)" "$(ROOTFS_TEMPLATE)" "$(INIT_FILE)" "$(abspath $(ROOTFS_DIR))" "$(BUSYBOX_CC)" "$(JOBS)"

.PHONY: initramfs
initramfs: $(INITRAMFS)

$(INITRAMFS): rootfs scripts/build-initramfs.sh | $(OUT_DIR)
	sh scripts/build-initramfs.sh "$(ROOTFS_DIR)" "$@"

.PHONY: run
run: all
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)"

.PHONY: smoke
smoke: all
	@set -eu; \
	status=0; \
	QEMU_MEMORY="$(QEMU_MEMORY)" QEMU_APPEND="$(QEMU_APPEND)" timeout $(SMOKE_TIMEOUT) sh scripts/run-qemu.sh "$(KERNEL_IMAGE)" "$(INITRAMFS)" > $(OUT_DIR)/qemu-smoke.log 2>&1 || status=$$?; \
	if [ "$$status" != "0" ] && [ "$$status" != "124" ]; then \
		cat $(OUT_DIR)/qemu-smoke.log; \
		exit "$$status"; \
	fi; \
	grep -q "MENTAT_LINUX_PHASE2_BOOT_OK" $(OUT_DIR)/qemu-smoke.log; \
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
