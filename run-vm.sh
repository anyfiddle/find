exec docker run \
    -ti \
    -v /home/joji/firecracker/find/image.ext4:/image.ext4 \
    -p 8022:22 \
    -p 8080:80 \
    --privileged \
    find --root-drive=/image.ext4