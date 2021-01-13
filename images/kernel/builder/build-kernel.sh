#!/bin/sh

git clone https://github.com/torvalds/linux.git /workspace/kernel 2> /dev/null || (cd /workspace/kernel ; git pull)
cd /workspace/kernel
git checkout v4.19
cp /workspace/.config ./
cat .config
make vmlinux
cp ./vmlinux /output