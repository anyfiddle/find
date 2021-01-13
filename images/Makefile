DOCKER=docker

ROOTFS_BUILDER_IMAGE_NAME=anyfiddle/firecracker-rootfs-builder
KERNEL_BUILDER_IMAGE_NAME=anyfiddle/firecracker-kernel-builder

ROOTFS_DOCKER_IMAGE_NAME?=
ROOTFS_BUILD_DIR?=
KERNEL_BUILD_DIR?=

rootfs-builder:
	$(DOCKER) build -t $(ROOTFS_BUILDER_IMAGE_NAME) ./rootfs/builder

kernel-builder:
	$(DOCKER) build -t $(KERNEL_BUILDER_IMAGE_NAME) ./kernel/builder

build-rootfs-docker:
	$(DOCKER) build -t $(ROOTFS_DOCKER_IMAGE_NAME) $(CURDIR)/rootfs/$(ROOTFS_BUILD_DIR)
	$(DOCKER) run \
		--privileged \
		-v $(CURDIR)/output:/output \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-ti $(ROOTFS_BUILDER_IMAGE_NAME) $(ROOTFS_DOCKER_IMAGE_NAME)

build-kernel:
	$(DOCKER) run \
		-v $(CURDIR)/output:/output \
		-v $(CURDIR)/../../linux-kernel-source:/workspace/kernel \
		-v $(CURDIR)/kernel/$(KERNEL_BUILD_DIR)/.config:/workspace/.config \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-ti $(KERNEL_BUILDER_IMAGE_NAME)

build-ubuntu-rootfs-docker:
	$(MAKE) build-rootfs-docker ROOTFS_DOCKER_IMAGE_NAME=anyfiddle/firecracker-ubuntu ROOTFS_BUILD_DIR=ubuntu-docker

build-default-kernel:
	$(MAKE) build-kernel KERNEL_BUILD_DIR=default-kernel