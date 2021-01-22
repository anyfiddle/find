exec docker run \
    -ti \
    --privileged \
    -v $(pwd)/../vmdisk:/disk \
    -p 8022:22 \
    -p 9876:9876 \
    -p 8080:8080 \
    -e ROOTFS_PATH=/disk/image.ext4
    anyfiddle/find:0.0.2
