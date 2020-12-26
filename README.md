# Firecracker IN Docker

FIND is a project to run Firecracker MicroVMs in Docker containers

## Getting started

### Build container
```
docker build -t find .
```

### Run Firecracker in Docker
```
docker run \
    -ti \
    --privileged \
    find
```

This will run the firecracker with hello kernel and root drive provided for testing by Firecracker


## Using Custom kernel and rootfs

### Download custom kernel and rootfs
```
curl -fsSL -o /output/vmlinux.bin https://s3.amazonaws.com/spec.ccfc.min/img/hello/kernel/hello-vmlinux.bin
curl -fsSL -o /output/rootfs.ext4 https://s3.amazonaws.com/spec.ccfc.min/img/hello/fsfiles/hello-rootfs.ext4
```

Now run the container with the kernel and rootfs mounted and added to params

```
docker run \
    -ti \
    -v ${pwd}/output/vmlinux.bin:/vmlinux.bin \
    -v ${pwd}/output/rootfs.ext4:/rootfs.ext4 \
    --privileged \
    find --kernel=/vmlinux.bin --root-drive=/rootfs.ext4
```

### Build your own kernel and/or rootfs

Build the kernel and image inside a container and output it to a mounted folder

```
docker run -v ${pwd}/output:/output anyfiddle/firecracker-builder
```