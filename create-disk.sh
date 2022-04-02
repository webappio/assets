#!/usr/bin/env bash

sudo umount build/root
sudo rm -rf build/root

set -eu -o pipefail

rm -rf build
mkdir -p build
cd build

fallocate -l 50G webapproot.ext4
mkfs.ext4 webapproot.ext4

mkdir root
sudo mount -o loop webapproot.ext4 $(pwd)/root

curl https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-root.tar.xz | sudo tar -C $(pwd)/root -xJf /dev/stdin

cat << EOF | sudo chroot root
echo -e 'password\npassword' | passwd
rm -f /etc/legal
chmod -x /etc/update-motd.d/*
rm -rf /var/lib/apt/lists/*
chmod a-x /usr/lib/ubuntu-release-upgrader/release-upgrade-motd
echo fs.inotify.max_user_watches=524288 > /etc/sysctl.d/99-ubuntu-go.conf

cat <<ZZZZ >/etc/apt/apt.conf.d/90assumeyes
APT::Get::Assume-Yes "true";
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
ZZZZ

sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
sed -i '$ a PermitRootLogin yes' /etc/ssh/sshd_config

sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
sed -i '$ a PasswordAuthentication yes' /etc/ssh/sshd_config

rm /etc/fstab
( cd /etc/ssh; ssh-keygen -A; )

rm /etc/resolv.conf
echo 'nameserver 10.111.1.1' > /etc/resolv.conf

rm -f /lib/systemd/system/sysinit.target.wants/systemd-random-seed.service

EOF

sudo umount $(pwd)/root

