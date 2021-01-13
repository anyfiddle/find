exec docker run \
    -ti \
    -v /home/joji/firecracker/find/images/output/image.ext4:/image.ext4 \
    -v /home/joji/firecracker/find/images/output/vmlinux:/vmlinux.bin \
    -p 8022:22 \
    -p 8080:8080 \
    --privileged \
    find --root-drive=/image.ext4 --kernel=/vmlinux.bin