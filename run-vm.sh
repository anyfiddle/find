exec docker run \
    -ti \
    --privileged \
    -v $(pwd)/../vmdisk:/disk \
    -p 8022:22 \
    -p 9876:9876 \
    -p 8080:8080 \
    -e ROOTFS_PATH=/disk/image.ext4\
    -e SNAPSHOT_PATH=/disk/snapshot\
    -e MEM_FILE_PATH=/disk/memfile\
    anyfiddle/find:0.0.3
