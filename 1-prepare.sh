#!/usr/bin/env bash
set -e -u

TARGET_DEVICE=/dev/sda

echo
echo +++ Init Pacman
pacman-key --init
pacman-key --populate archlinux

echo
echo +++ Install some tools
pacman --noconfirm -Sy dosfstools btrfs-progs

echo
echo +++ Set partition table
wipefs --all ${TARGET_DEVICE}
cat <<SFDISK | sfdisk ${TARGET_DEVICE}
label: gpt
name="ZenBoot", size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
name="ZenArch", type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
SFDISK

echo
echo +++ Create and mount filesystems
BOOT_DEV=${TARGET_DEVICE}1
ARCH_DEV=${TARGET_DEVICE}2

mkfs.vfat -F32 -n zen-boot ${BOOT_DEV}
mkfs.btrfs -f -L zen-arch ${ARCH_DEV}

# Separate tmp subvolume is created to prevent temporary files
# from snapshoting
mount ${ARCH_DEV} /mnt
btrfs subvolume create /mnt/root
btrfs subvolume create /mnt/root/tmp
umount /mnt
mount -t btrfs -o subvol=root ${ARCH_DEV} /mnt
mount -t btrfs -o subvol=root/tmp ${ARCH_DEV} /mnt/tmp

mkdir -p /mnt/boot
mount ${BOOT_DEV} /mnt/boot

mkdir -p /mnt/etc
genfstab -L /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab

echo
echo +++ Install base packages
pacstrap /mnt btrfs-progs base base-devel

echo
echo +++ Chrooting into target system
cp 2-install.sh /mnt/root
arch-chroot /mnt /root/2-install.sh
