#!/usr/bin/env bash

set -e -u

MIRROR=http://ftp.nluug.nl/os/Linux/distr/archlinux/iso/2018.09.01
IMG=archlinux-bootstrap-2018.09.01-x86_64.tar.gz
ROOT=arch-root

echo
echo === Download bootstrap image
wget --no-verbose --show-progress --continue ${MIRROR}/${IMG} -P /tmp
wget --no-verbose --show-progress --continue ${MIRROR}/${IMG}.sig -P /tmp

echo
echo === Check signature
gpg --keyserver-options auto-key-retrieve --verify /tmp/${IMG}.sig /tmp/${IMG}

echo
echo === Extract to ${ROOT}
sudo rm -rf ${ROOT}
mkdir ${ROOT}
tar xzf /tmp/${IMG} -C ${ROOT} --strip-components=1

echo
echo === \"Fix\" Mirrorlist and pacman.conf
sudo sed -i s/#Server/Server/ ${ROOT}/etc/pacman.d/mirrorlist
sudo sed -i 's/^[[:space:]]*\(CheckSpace\)/# \1/' ${ROOT}/etc/pacman.conf

echo
echo === Chrooting
sudo cp 1-prepare.sh 2-install.sh ${ROOT}/root
sudo ${ROOT}/bin/arch-chroot ${ROOT} /root/1-prepare.sh
