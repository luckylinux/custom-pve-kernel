#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Abort on Error
set -e

# Define Custom Suffix
CUSTOM_SUFFIX="patched"

# Define Version
# proxmox_kernel_original_version="linux-headers-6.8.12-3-pve"
proxmox_kernel_original_release="linux-headers-6.8.12-3-pve"
proxmox_kernel_original_branch="bookworm-6.8"
proxmox_kernel_use_git="yes"

# Install Requirements for building Kernel from Source
# apt-get update
# apt-get install -y build-essential git git-email debhelper pve-doc-generator devscripts python-is-python3 dh-python sphinx-common quilt libunwind-dev libzstd-dev pkg-config equivs

# Clone Git Repository
if [[ ! -d "./.git" ]]
then
    git clone https://git.proxmox.com/git/pve-kernel.git
else
    git pull
fi

cd pve-kernel

# Initialize / Update Submodules
make submodule
git submodule foreach git fetch --tags
git submodule update --init

# Configure Custom Suffix
./scripts/config --file "$configfile" --set-str CONFIG_LOCALVERSION "${CUSTOM_SUFFIX}"

## (ex: ZFS_SHA1=zfs-2.2.0 and KERNEL_SHA1=cod/mainline/v6.5.7)
ZFS_SHA1=
KERNEL_SHA1=
make prep ZFS_SHA1= KERNEL_SHA1=
make build-dir-fresh ZFS_SHA1= KERNEL_SHA1=
mk-build-deps -ir proxmox-kernel-*/debian/conrol
mk-build-deps -ir proxmox-kernel-*/modules/pkg-zfs/debian/control

# compile kernel
make deb ZFS_SHA1= KERNEL_SHA1=

# Install Debian Packages
## you need this package so os-prober hook script for grub doesn't complain and
## you don't get a "can't find /scripts/zfs" on boot
apt install zfs-initramfs
apt install ./proxmox-headers-..._amd64.deb ./proxmox-kernel-..._amd64.deb
