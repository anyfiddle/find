# Firecracker IN Docker

FIND is a project to run Firecracker MicroVMs in Docker containers

## Getting started

### Requirements

- KVM enabled host. Either bare metal instance or VM with nested virtualisation [Cloud providers with KVM supported VMs](https://github.com/weaveworks/ignite/blob/master/docs/cloudprovider.md)

### Run Firecracker in Docker

Download RootFS image

```
curl -fsSL -o rootfs.ext4 https://storage.googleapis.com/anyfiddle-find/rootfs/ubuntu-image-latest.ext4
```

```
docker run \
    -ti \
    --privileged \
    -v $(pwd)/rootfs.ext4:/rootfs.ext4 \
    -e ROOTFS_PATH=/rootfs.ext4 \
    anyfiddle/find
```

This will run the firecracker with hello kernel and root drive provided for testing by Firecracker

### Run with other kernel or rootfs

Mount vmlinux (kernel) or rootfs into the FIND container and pass the location as params

```
docker run \
    -ti \
    --privileged \
    -v ${pwd}/rootfs.ext4:/rootfs.ext4 \
    -v ${pwd}/vmlinux.bin:/vmlinux.bin \
    -e ROOTFS_PATH=/rootfs.ext4 \
    -e KERNEL_PATH=/vmlinux.ext4 \
    anyfiddle/find
```

## Contributing

### Building FIND container image

```
docker build -t find .
```

## Related Repositories

- Firecracker rootfs builder : https://github.com/anyfiddle/firecracker-rootfs-builder
- Firecracker kernel builder : https://github.com/anyfiddle/firecracker-kernel-builder
- Ubuntu Rootfs for FIND from docker image : https://github.com/anyfiddle/docker-find-ubuntu
- Initializing volume for starting FIND in kubernetes : https://github.com/anyfiddle/kubecracker-init
