#!/usr/bin/env bash
set -e -u

echo
echo %%% Basic config


# Setting font and locale for virtual console (the one that you see after pressing Ctrl+Alt+Fx).
# Keymap, among other things, determines keys combination to switch layouts.
# Available fonts and keymaps are at `/usr/share/kbd/{consolefonts,keymaps}`.
# You can use `loadkeys` and `setfont` tools to try them.
# To apply those settings during boot process you need to add
# `consolefont` and `keymap` hooks to `/etc/mkinitcpio.conf`.

pacman --noconfirm -S terminus-font

cat > /etc/vconsole.conf <<EOF
KEYMAP=ruwin_cplk-UTF-8
FONT=ter-v16n
EOF

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

cat > /etc/locale.gen <<EOF
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
EOF
locale-gen

cat > /etc/locale.conf <<EOF
LANG=en_US.UTF-8
EOF



cat > /etc/hostname <<EOF
zen
EOF

cat > /etc/hosts <<EOF
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

pacman --noconfirm -S sudo
useradd --create-home user
usermod -aG wheel user

cat > /etc/sudoers <<EOF
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
user ALL = NOPASSWD: /bin/pacman
EOF

usermod -p '$6$LfB.6Fj5V73E$IGknZSwJXStP94B.s8HcPOyxdfORmun3NyuAUqv5Fw9IWSi6zKQNXthFmBoo8rdE9g.K2xlAUtzIeUY7djYqn/' root
usermod -p '$6$vQ1AC/Opv$ajJDiafmKPUY.zMnEsJCgbkYs4drRxGS9sVb/5fnP3P8BJWBCaxuQK8o.LbMrXoRA3wGlT7vTr3m4gWOj89z/0' user

pacman --noconfirm -S base-devel go git bash-completion
# TODO: configure makepkg for optimized builds


cat <<EOF | sudo -u user bash
cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm --skippgpcheck
cd - && rm -rf yay
EOF


echo
echo %%% Mkinitcpio
cat > /etc/mkinitcpio.conf <<EOF
# crc32c-intel allows to use hardware CRC calculation in BTRFS
MODULES=(btrfs crc32c-intel)
# it is handy to have btrfs tools in recovery console
BINARIES=(/usr/bin/btrfs)
FILES=()
HOOKS=(base consolefont keymap udev autodetect modconf block filesystems keyboard fsck)
EOF

# FIXME: i915 https://wiki.archlinux.org/index.php/Intel_graphics

### FIXME: https://gist.github.com/imrvelj/c65cd5ca7f5505a65e59204f5a3f7a6d
sudo -u user yay --noconfirm -S aic94xx-firmware wd719x-firmware
mkinitcpio -p linux


echo
echo %%% Install bootloader
pacman --noconfirm -S intel-ucode
bootctl --path=/boot install

mkdir -p /boot/loader/entries
cat > /boot/loader/loader.conf <<EOF
idefault arch
timeout  1
editor   yes
console-mode max
EOF

# TODO: add restore console to boot menu
cat > /boot/loader/entries/arch.conf <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=LABEL=zen-arch rootfstype=btrfs rootflags=subvol=root rw
EOF

# Automatically update /boot when systemd is upgraded
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/systemd-boot.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF

echo
echo !!! Install GUI related packages


# FIXME: install gvim with +clipboard support
# FIXME: global config to have nice VIM under root
# configure vim
mkdir -p ~/.vim/undodir
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# run :PlugInstall to install plugins
# :PlugStatus to check plugins

# tagbar plugin requires ctags, we use universal-ctags
# TODO: Why universal? Why tagbar?
yay -S universal-ctags
yay -S hasktags

# Better grep. Integrates well with fzf.vim
yay -S ripgrep


# fonts with glyphs.
# https://github.com/ryanoasis/nerd-fonts
yay -S nerd-fonts-complete-mono-glyphs


# connman with WiFi support
sudo -u user yay --noconfirm -S dialog wpa_supplicant

sudo -u user yay --noconfirm -S vulkan-intel ## explain why we need this
sudo -u user yay --noconfirm -S wlroots-git sway-wlroots-git termite

# Autologin first console and run sway
# Override `Type=idle` with `Type=simple` to run `agetty` in parallel with other services.
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
Type=simple
ExecStart=
ExecStart=-/usr/bin/agetty --autologin user --noclear %I $TERM
EOF

# Screenshots in sway
sudo -u user yay --noconfirm -S wl-clipboard slurp grim

# wl-copy copies image to clipboard, slurp allows to select screen region
# $ grim -g "$(slurp)" - | wl-copy
# $ grim ~/$(date +'%FT%T%z.png')


# TODO: enable Framebuffer compression https://wiki.archlinux.org/index.php/Intel_graphics

# TODO: video acceleration: https://wiki.archlinux.org/index.php/Hardware_video_acceleration
sudo -u user yay --noconfirm -S libva-mesa-driver libva-intel-driver intel-media-driver mplayer-vaapi

pacman --noconfirm -S alsa-utils

# Power saving
# - intel-undervolt

# powertop auto-tune on startup
# FIXME: do i need to enable it somehow?
cat > /etc/systemd/system/powertop.service <<EOF
[Unit]
Description=Powertop tunings

[Service]
ExecStart=/usr/bin/powertop --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

echo
echo !!! Ready to reboot

