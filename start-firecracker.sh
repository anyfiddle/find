#!/bin/bash

genMAC () {
  hexchars="0123456789ABCDEF"
  end=$( for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  echo "FE:05$end"
}

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

tapDeviceMac=$(genMAC)

# containerMAC=$(ip link show eth0 | awk '/ether/ { print $2 }')
# newContainerMac=$(genMAC)

# echo "Assign new MAC address to container : ${newContainerMac}"
# ip link set eth0 down
# ip link set eth0 address ${newContainerMac}
# ip link set eth0 up

echo "Setting up tap device"
ip tuntap add tap0 mode tap

ip addr add 172.16.0.1/24 dev tap0
ip link set dev tap0 up

sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"


IPs=$(ip address show dev eth0 | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)
IPs=($IPs)
IP=${IPs[0]}

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -I FORWARD 1 -i tap0 -j ACCEPT
iptables -I FORWARD 1 -o tap0 -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -t nat -A PREROUTING -d $IP -j DNAT --to-destination 172.16.0.2



# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT


# echo "Setting up routing to firecracker VM IP"
# iptables -t nat -A PREROUTING -p tcp -j DNAT --to-destination 172.16.0.2:80
# iptables -t nat -A POSTROUTING -j MASQUERADE

echo "Staring firecracker..."
echo "Using kernel : ${kernel}"
echo "Using root drive : ${rootfs}"
echo "Using MAC address of container : ${containerMAC}"

exec firectl --kernel=${kernel} --root-drive=${rootfs} --tap-device=tap0/${tapDeviceMac} $@