# Firecracker IN Docker

FIND is a project to run Firecracker MicroVMs in Docker containers

## Getting started

### Run Firecracker in Docker

Download RootFS image

```
curl -fsSL -o image.ext4 https://storage.googleapis.com/anyfiddle-find/rootfs/ubuntu-image-latest.ext4
```

```
docker run \
    -ti \
    --privileged \
    -v $(pwd)/rootfs.ext4:/image.ext4 \
    -e ROOTFS_PATH=/image.ext4 \
    anyfiddle/find
```

This will run the firecracker with hello kernel and root drive provided for testing by Firecracker

### Run with other kernel or rootfs

Mount vmlinux (kernel) or rootfs into the FIND container and pass the location as params

```
docker run \
    -ti \
    -v ${pwd}/vmlinux.bin:/vmlinux.bin \
    -v ${pwd}/rootfs.ext4:/rootfs.ext4 \
    --privileged \
    anyfiddle/find --kernel=/vmlinux.bin --root-drive=/rootfs.ext4
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
