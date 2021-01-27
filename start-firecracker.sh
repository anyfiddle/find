#!/bin/bash

: ${KERNEL_PATH="/find/vmlinux.bin"}
: ${SOCKET_PATH="/tmp/firecracker-socket"}

: ${GATEWAY_IP="172.16.0.1"}
: ${VM_IP="172.16.0.2"}
: ${TAP_DEVICE_NAME="tap0"}

: ${CPU_COUNT="1"}
: ${MEMORY="1024"}

NETWORK_IP=""

if [ -z "$ROOTFS_PATH" ]
then
  echo "Invalid params"
  echo "root-drive parameter required"
  echo "Add environment variable ROOTFS_PATH=<PATH_TO_ROOT_FS_IMAGE>"  
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
  NETWORK_IP=${ifaceIPs[0]}

  echo "Setting up tap device"
  ip tuntap add mode tap $TAP_DEVICE_NAME
  ip addr add $GATEWAY_IP/24 dev $TAP_DEVICE_NAME
  ip link set dev "$TAP_DEVICE_NAME" up

  echo "Setting up routing to and from TAP device to Internet"
  sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
  iptables -t nat -A POSTROUTING -o $iface -j MASQUERADE
  iptables -I FORWARD 1 -i $TAP_DEVICE_NAME -j ACCEPT
  iptables -I FORWARD 1 -o $TAP_DEVICE_NAME -m state --state RELATED,ESTABLISHED -j ACCEPT

  iptables -t nat -A PREROUTING -d $NETWORK_IP -j DNAT --to-destination $VM_IP

  echo "Networking"
  echo "\t Network interface IP (Ethernet) : ${NETWORK_IP}"
  echo "\t Tap device : ${TAP_DEVICE_NAME}"
  echo "\t Tap device IP (Gateway) : ${GATEWAY_IP}"
  echo "\t VM IP : ${VM_IP}"
}

function loadKernel() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/boot-source'   \
    -H 'Accept: application/json'           \
    -H 'Content-Type: application/json'     \
    -d "{
          \"kernel_image_path\": \"${KERNEL_PATH}\",
          \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
    }"
}

function loadRootFs() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/drives/rootfs' \
    -H 'Accept: application/json'           \
    -H 'Content-Type: application/json'     \
    -d "{
          \"drive_id\": \"rootfs\",
          \"path_on_host\": \"${ROOTFS_PATH}\",
          \"is_root_device\": true,
          \"is_read_only\": false
    }"
}

function loadNetworkDevice() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/network-interfaces/eth0' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{
        \"iface_id\": \"eth0\",
        \"guest_mac\": \"${TAP_DEVICE_MAC}\",
        \"host_dev_name\": \"${TAP_DEVICE_NAME}\"
      }"
}

function loadMachineConfig() {
  curl -s --unix-socket ${SOCKET_PATH} -i  \
    -X PUT 'http://localhost/machine-config' \
    -H 'Accept: application/json'            \
    -H 'Content-Type: application/json'      \
    -d "{
        \"vcpu_count\": ${CPU_COUNT},
        \"mem_size_mib\": ${MEMORY},
        \"ht_enabled\": false
    }"
}

function startVM() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/actions'       \
    -H  'Accept: application/json'          \
    -H  'Content-Type: application/json'    \
    -d '{
        "action_type": "InstanceStart"
    }'
}

function pauseVM() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PATCH 'http://localhost/vm' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
            "state": "Paused"
    }'
}

function resumeVM() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PATCH 'http://localhost/vm' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{
            "state": "Resumed"
    }'
}

function createSnapshot() {
  curl -s --unix-socket ${SOCKET_PATH} -i \
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
  curl -s --unix-socket ${SOCKET_PATH} -i \
    -X PUT 'http://localhost/snapshot/load' \
    -H  'Accept: application/json' \
    -H  'Content-Type: application/json' \
    -d "{
            \"snapshot_path\": \"${SNAPSHOT_PATH}\",
            \"mem_file_path\": \"${MEM_FILE_PATH}\"
        }"
}

function initSocket() {
  rm ${SOCKET_PATH}
}

function startFirecrackerServer() {
  firecracker --api-sock ${SOCKET_PATH} &
}

function startFromImage() {
  loadKernel
  loadRootFs
  loadMachineConfig
  loadNetworkDevice
  startVM
}

function startFromSnapshot() {
  loadSnapshot
  resumeVM
}

function startFirecrackerVM() {
  waitForFirecrackerServer
  if [ ! -f "${SNAPSHOT_PATH}" ] && [ ! -f "${MEM_FILE_PATH}" ]
  then
    echo "Starting from image"
    startFromImage
  else
    echo "Starting from snapshot"
    startFromSnapshot
  fi
}

function waitForFirecrackerServer() {
  echo "Waiting for firecracker server to start..."
  while ! curl --unix-socket ${SOCKET_PATH} "http://localhost"
  do
    sleep 1
  done
  echo "Firecracker server starter"
}

function handleStop() {
  if [ ! -z "${SNAPSHOT_PATH}" ] && [ ! -z "${MEM_FILE_PATH}" ]
  then
    echo "Pausing VM"
    pauseVM

    echo "Removing previous snapshot files"
    if [ -f "${SNAPSHOT_PATH}" ]
    then
      rm ${SNAPSHOT_PATH}
    fi

    if [ -f "${MEM_FILE_PATH}" ]
    then
      rm ${MEM_FILE_PATH}
    fi

    echo "Taking snapshot ${SNAPSHOT_PATH}"
    createSnapshot

    echo "Snapshot done"
  fi

  kill $firecrackerPid
}


TAP_DEVICE_MAC=$(genMAC)
echo "Staring firecracker..."
echo "Using kernel : ${KERNEL_PATH}"
echo "Using root drive : ${ROOTFS_PATH}"


trap handleStop INT
trap handleStop TERM

initSocket
setupNetworking


# # Start firecracker process
startFirecrackerServer

startFirecrackerVM

firecrackerPid=$!
wait $firecrackerPid
