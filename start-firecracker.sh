#!/bin/bash


# ContainsElement: checks if first parameter is among the array given as second parameter
# returns 0 if the element is found in the list and 1 if not
# usage: containsElement $item $list

containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Generate random MAC address
genMAC () {
  hexchars="0123456789ABCDEF"
  end=$( for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  echo "FE:05$end"
}

# atoi: Returns the integer representation of an IP arg, passed in ascii
# dotted-decimal notation (x.x.x.x)
atoi() {
  IP=$1
  IPnum=0
  for (( i=0 ; i<4 ; ++i ))
  do
    ((IPnum+=${IP%%.*}*$((256**$((3-${i}))))))
    IP=${IP#*.}
  done
  echo $IPnum
}

# itoa: returns the dotted-decimal ascii form of an IP arg passed in integer
# format
itoa() {
  echo -n $(($(($(($((${1}/256))/256))/256))%256)).
  echo -n $(($(($((${1}/256))/256))%256)).
  echo -n $(($((${1}/256))%256)).
  echo $((${1}%256))
}

cidr2mask() {
  local i mask=""
  local full_octets=$(($1/8))
  local partial_octet=$(($1%8))

  for ((i=0;i<4;i+=1)); do
    if [ $i -lt $full_octets ]; then
      mask+=255
    elif [ $i -eq $full_octets ]; then
      mask+=$((256 - 2**(8-$partial_octet)))
    else
      mask+=0
    fi
    test $i -lt 3 && mask+=.
  done

  echo $mask
}

# Generates and returns a new IP and MASK in a superset (inmediate wider range)
# of the given IP/MASK
# usage: getNonConflictingIP IP MASK
# returns NEWIP MASK
getNonConflictingIP () {
    local IP="$1"
    local CIDR="$2"

    let "newCIDR=$CIDR-1"

    local i=$(atoi $IP)
    let "j=$i^(1<<(32-$CIDR))"
    local newIP=$(itoa j)

    echo $newIP $newCIDR
}

# generates unused, random names for macvlan or bridge devices
# usage: generateNetDevNames DEVICETYPE
#   DEVICETYPE must be either 'macvlan' or 'bridge'
# returns:
#   - bridgeXXXXXX if DEVICETYPE is 'bridge'
#   - macvlanXXXXXX, macvtapXXXXXX if DEVICETYPE is 'macvlan'
generateNetdevNames () {
  devicetype=$1

  local netdevinterfaces=($(ip link show | awk "/$devicetype/ { print \$2 }" | cut -d '@' -f 1 | tr -d :))
  local randomID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 6 | head -n 1)

  # check if the device already exists and regenerate the name if so
  while containsElement "$devicetype$randomID" "${netdevinterfaces[@]}"; do randomID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 6 | head -n 1); done

  echo "$randomID"
}

# Crate tap device with interface mac and ip
setupTap () {
  set -x
  local iface="$1"
  local tapName="$2"


  NAMESERVER=`grep "nameserver " /etc/resolv.conf | cut -f 2 -d ' '`
  NAMESERVERS=`echo ${NAMESERVER[*]} | sed "s/ /,/g"`
  NETWORK_IP="${NETWORK_IP:-$(echo 172.$((RANDOM%(31-16+1)+16)).$((RANDOM%256)).$((RANDOM%(254-2+1)+2)))}"
  NETWORK_SUB=`echo $NETWORK_IP | cut -f1,2,3 -d\.`
  NETWORK_GW="${NETWORK_GW:-$(echo ${NETWORK_SUB}.1)}"

 
  ip tuntap add mode tap $tapName

  dnsmasq --user=root \
	  --dhcp-range=$NETWORK_IP,$NETWORK_IP \
	  --dhcp-option=option:router,$NETWORK_GW \
          --dhcp-option=option:dns-server,$NAMESERVERS

  ip addr add $NETWORK_GW/24 dev $tapName
  ip link set dev "$tapName" up

  iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
  iptables -I FORWARD 1 -i $tapName -j ACCEPT
  iptables -I FORWARD 1 -o $tapName -m state --state RELATED,ESTABLISHED -j ACCEPT

  iptables -t nat -A PREROUTING -d $IP -j DNAT --to-destination $NETWORK_IP


  # Append MAC and respective IP address to the net-conf file
  echo -e "IP=$NETWORK_IP" >> /tmp/net-conf
  echo -e "GATEWAY=$NETWORK_GW" >> /tmp/net-conf
}


# Setup tap device to connect to the VM for the given interface
# and setup the ip addresses
configureNetworks () {
  local i=0

  local GATEWAY=$(ip r | grep default | awk '{print $3}')
  local IP

  /sbin/sysctl -w net.ipv4.conf.all.forwarding=1

  # Create the net-conf file that will be mounted as env drive
  for iface in "${local_ifaces[@]}"; do

    IPs=$(ip address show dev $iface | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)
    IPs=($IPs)
    MAC=$(ip link show $iface | awk '/ether/ { print $2 }')
    log "DEBUG" "Container original MAC address: $MAC"

    IP=${IPs[0]}

    local CIDR=$(ip address show dev $iface | awk "/inet $IP/ { print \$2 }" | cut -f2 -d/)

    # use container MAC address ($MAC) for tap device
    # and generate a new one for the local interface
    ip link set $iface down
    ip link set $iface address $(genMAC)
    ip link set $iface up

    tapDeviceParam=""

    local deviceID=$(generateNetdevNames "bridge")
    local tapName="tap-$deviceID"

    # setup the tap device for connecting the VM
    setupTap $iface $tapName
    # firectl configuration:
    tapDeviceParam="--tap-device=$tapName/$MAC"

    log "DEBUG" "tapName: $tapName"
    let i++

  done
}

# Create docker host conatiner configuration image file that will be mounted as a drive
createHostConfDrive() {
	drivePath="/tmp/hostconf"

	dd if=/dev/zero of=$drivePath bs=1M count=2
	mkfs.ext4 $drivePath

	mkdir /tmp/hostconffs-mount
	mount $drivePath /tmp/hostconffs-mount -o loop
	cp /tmp/net-conf /tmp/hostconffs-mount/net-conf
	cp /etc/hosts /tmp/hostconffs-mount/hosts
	cp /etc/resolv.conf /tmp/hostconffs-mount/resolv.conf
	umount /tmp/hostconffs-mount

  networkConfigDriveParam="--add-drive=$drivePath:ro"
}

echo "Starting Configuration... \n"

FIRECTL_DRIVE_OPTS=""

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

# containerMAC=$(ip link show eth0 | awk '/ether/ { print $2 }')
# newContainerMac=$(genMAC)

# echo "Assign new MAC address to container : ${newContainerMac}"
# ip link set eth0 down
# ip link set eth0 address ${newContainerMac}
# ip link set eth0 up

# echo "Setting up tap device"
# ip tuntap add tap0 mode tap

# ip addr add 172.16.0.1/24 dev tap0
# ip link set tap0 up
# sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
# iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
# iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT



local_ifaces=($(ip link show | grep -v noop | grep state | grep -v LOOPBACK | awk '{print $2}' | tr -d : | sed 's/@.*$//'))
local_bridges=($(brctl show | tail -n +2 | awk '{print $1}'))
# Get non-bridge interfaces:
for i in "${local_bridges[@]}"
do
  local_ifaces=(${local_ifaces[@]//*$i*})
done
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

configureNetworks
createHostConfDrive

echo "Staring firecracker..."
echo "Using kernel : ${kernel}"
echo "Using root drive : ${rootfs}"
echo "Using MAC address of container : ${containerMAC}"

exec firectl --kernel=${kernel} --root-drive=${rootfs} ${tapDeviceParam} ${networkConfigDriveParam} $@