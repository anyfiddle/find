#!/bin/bash

genMAC () {
  hexchars="0123456789ABCDEF"
  end=$( for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  echo "FE:05$end"
}

kernel=/find/vmlinux.bin

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

if [ -z "$rootfs" ]
then
  echo "Invalid params"
  echo "root-drive parameter required"
  echo "Use --root-drive=<PATH_TO_ROOT_FS_IMAGE>"  
  exit 1
fi

iface=eth0
tapDeviceName=tap0
tapDeviceMac=$(genMAC)
gatewayIP=172.16.0.1
vmIP=172.16.0.2

ifaceIPs=$(ip address show dev $iface | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)
ifaceIPs=($ifaceIPs)
ifaceIP=${ifaceIPs[0]}

echo "Setting up tap device"
ip tuntap add mode tap $tapDeviceName
ip addr add $gatewayIP/24 dev $tapDeviceName
ip link set dev "$tapDeviceName" up

echo "Setting up routing to and from TAP device to Internet"
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
iptables -I FORWARD 1 -i $tapDeviceName -j ACCEPT
iptables -I FORWARD 1 -o $tapDeviceName -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -t nat -A PREROUTING -d $ifaceIP -j DNAT --to-destination $vmIP

echo "Staring firecracker..."
echo "Using kernel : ${kernel}"
echo "Using root drive : ${rootfs}"
echo "Networking"
echo "\t Network interface IP (Ethernet) : ${ifaceIP}"
echo "\t Tap device : ${tapDeviceName}"
echo "\t Tap device IP (Gateway) : ${gatewayIP}"
echo "\t VM IP : ${vmIP}"

exec firectl --kernel=$kernel --root-drive=$rootfs --tap-device=$tapDeviceName/$tapDeviceMac $@