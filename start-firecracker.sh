#!/usr/bin/env bash

kernel_path="$(pwd)/vmlinux.bin"
rootfs_path="$(pwd)/build/webapproot.ext4"

TAP_DEV="fc-88-tap0"

# set up the kernel boot args
MASK_LONG="255.255.255.252"
MASK_SHORT="/30"
FC_IP="169.254.0.21"
TAP_IP="169.254.0.22"
FC_MAC="02:FC:00:00:00:05"

KERNEL_BOOT_ARGS="ro console=ttyS0 noapic reboot=k panic=1 pci=off nomodules random.trust_cpu=on"
KERNEL_BOOT_ARGS="${KERNEL_BOOT_ARGS} ip=${FC_IP}::${TAP_IP}:${MASK_LONG}::eth0:off"

# set up a tap network interface for the Firecracker VM to user
sudo ip link del "$TAP_DEV" 2> /dev/null || true
sudo ip tuntap add dev "$TAP_DEV" mode tap
sudo sysctl -w net.ipv4.conf.${TAP_DEV}.proxy_arp=1 > /dev/null
sudo sysctl -w net.ipv6.conf.${TAP_DEV}.disable_ipv6=1 > /dev/null
sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
sudo ip link set dev "$TAP_DEV" up

# make a configuration file
cat <<EOF > vmconfig.json
{
  "boot-source": {
    "kernel_image_path": "$kernel_path",
    "boot_args": "$KERNEL_BOOT_ARGS"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "$rootfs_path",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "network-interfaces": [
      {
          "iface_id": "eth0",
          "guest_mac": "$FC_MAC",
          "host_dev_name": "$TAP_DEV"
      }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  }
}
EOF

# start firecracker
firecracker --no-api --config-file vmconfig.json
