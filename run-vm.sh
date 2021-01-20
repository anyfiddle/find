exec docker run \
    -ti \
    -v $(pwd)/rootfs.ext4:/rootfs.ext4 \
    -p 8022:22 \
    -p 8080:8080 \
    --privileged \
    find --root-drive=/rootfs.ext4