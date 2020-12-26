#!/bin/sh

kernel=/find/vmlinux.bin
rootfs=/find/rootfs.ext4

while [ $# -gt 0 ]; do
  case "$1" in
    --kernel=*)
      kernel="${1#*=}"
      ;;
    --root-drive=*)
      rootfs="${1#*=}"
      ;;
  esac
  shift
done

echo "Setting up tap device"
ip tuntap add tap0 mode tap

ip addr add 172.16.0.1/24 dev tap0
ip link set tap0 up
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT

echo "Staring firecracker..."
echo "Using kernel : $kernel"
echo "Using root drive : $rootfs"

firectl --kernel=${kernel} --root-drive=${rootfs} --tap-device=tap0/AA:FC:00:00:00:01