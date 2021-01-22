#!/bin/bash

: ${KERNEL_PATH="/find/vmlinux.bin"}
: ${SOCKET_PATH="/tmp/firecracker-socket"}

: ${GATEWAY_IP="172.16.0.1"}
: ${VM_IP="172.16.0.2"}
: ${TAP_DEVICE_NAME="tap0"}

if [ -z "$ROOTFS_PATH" ]
then
  echo "Invalid params"
  echo "root-drive parameter required"
  echo "Use --root-drive=<PATH_TO_ROOT_FS_IMAGE>"  
  exit 1
fi


function genMAC () {
  hexchars="0123456789ABCDEF"
  end=$( for i in {1..8} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  echo "FE:05$end"
}

function setupNetworking() {
  iface=eth0

  ifaceIPs=$(ip address show dev $iface | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)
  ifaceIPs=($ifaceIPs)
  ifaceIP=${ifaceIPs[0]}

  echo "Setting up tap device"
  ip tuntap add mode tap $TAP_DEVICE_NAME
  ip addr add $GATEWAY_IP/24 dev $TAP_DEVICE_NAME
  ip link set dev "$TAP_DEVICE_NAME" up

  echo "Setting up routing to and from TAP device to Internet"
  sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
  iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
  iptables -I FORWARD 1 -i $TAP_DEVICE_NAME -j ACCEPT
  iptables -I FORWARD 1 -o $TAP_DEVICE_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT

  iptables -t nat -A PREROUTING -d $ifaceIP -j DNAT --to-destination $VM_IP
}

function loadKernel() {
  curl --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/boot-source'   \
    -H 'Accept: application/json'           \
    -H 'Content-Type: application/json'     \
    -d "{
          \"kernel_image_path\": \"${KERNEL_PATH}\",
          \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
    }"
}

function loadRootFs() {
  curl --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/drives/rootfs' \
    -H 'Accept: application/json'           \
    -H 'Content-Type: application/json'     \
    -d "{
          \"drive_id\": \"rootfs\",
          \"path_on_host\": \"${ROOTFS_PATH}\",
          \"is_root_device\": true,
          \"is_read_only\": false
    }"

function startVM() {
  curl --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/actions'       \
    -H  'Accept: application/json'          \
    -H  'Content-Type: application/json'    \
    -d '{
        "action_type": "InstanceStart"
    }'
}

function pauseVM() {
  curl --unix-socket /root/.firecracker.sock-7-81 -i \
    -X PATCH 'http://localhost/vm' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
            "state": "Paused"
    }'
}

function resumeVM() {
  curl --unix-socket /root/.firecracker.sock-7-81 -i \
    -X PATCH 'http://localhost/vm' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
            "state": "Resumed"
    }'
}

function createSnapshot() {
  curl --unix-socket /root/.firecracker.sock-7-81 -i \
    -X PUT 'http://localhost/snapshot/create' \
    -H  'Accept: application/json' \
    -H  'Content-Type: application/json' \
    -d "{
            \"snapshot_type\": \"Full\",
             \"snapshot_path\": \"${SNAPSHOT_PATH}\",
            \"mem_file_path\": \"${MEM_FILE_PATH}\"
    }"
}

function loadSnapshot() {
  curl --unix-socket /root/.firecracker.sock-7-81 -i \
    -X PUT 'http://localhost/snapshot/load' \
    -H  'Accept: application/json' \
    -H  'Content-Type: application/json' \
    -d "{
            \"snapshot_path\": \"${SNAPSHOT_PATH}\",
            \"mem_file_path\": \"${MEM_FILE_PATH}\"
        }"
}

function startFirecracker() {
  rm ${SOCKET_PATH}
  firecracker --api-sock ${SOCKET_PATH}
}

function loadVMFromImage() {
  loadKernel
  loadRootFs
  startVM
}

function loadVMFromSnapshot() {
  loadSnapshot
  resumeVM
}

function handleStop() {
  echo "Done $pid1 $pid2"
  kill $firecrackerPid
  kill $vmStarterPid
}


TAP_DEVICE_MAC=$(genMAC)
echo "Staring firecracker..."
echo "Using kernel : ${KERNEL_PATH}"
echo "Using root drive : ${ROOTFS_PATH}"
echo "Networking"
echo "\t Network interface IP (Ethernet) : ${ifaceIP}"
echo "\t Tap device : ${TAP_DEVICE_NAME}"
echo "\t Tap device IP (Gateway) : ${gatewayIP}"
echo "\t VM IP : ${VM_IP}"



trap handleStop INT
trap handleStop TERM

startFirecracker &
firecrackerPid=$!
echo "Firecracker PID: $firecrackerPid"

loadVMFromImage &
vmStarterPid=$!
echo "VM Starter PID: $vmStarterPid"

wait $firecrackerPid
wait $vmStarterPid
