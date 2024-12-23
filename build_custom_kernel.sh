#!/bin/bash

# Determine toolpath if not set already
relativepath="./" # Define relative path to go from this script to the root level of the tool
if [[ ! -v toolpath ]]; then scriptpath=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd ); toolpath=$(realpath --canonicalize-missing $scriptpath/$relativepath); fi

# Abort on Error
# set -e

# Enable Verbose Debugging
set -x

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
# apt-get install -y dh-python flex bison
# apt-get install --no-install-recommends -y asciidoc-base dwarves libdw-dev libiberty-dev libnuma-dev libslang2-dev lz4 xmlto

# DISABLED
# This pulls in a LOT of Dependencies including X11 and openjdk-17-jre
# Maybe better to use --no-install-recommends
# apt-get install --no-install-recommends pve-doc-generator

# Clone Git Repository
if [ ! -d "./pve-kernel" ] && [ ! -d "./pve-kernel/.git" ]
then
    git clone https://git.proxmox.com/git/pve-kernel.git
fi

# Change Folder
cd pve-kernel || exit

# Update Git Repository
git pull

# Checkout required Branch
git checkout "${proxmox_kernel_original_branch}"

# Initialize / Update Submodules
make submodule
git submodule foreach git fetch --tags
git submodule update --init

# Does NOT work
# sed -Ei "s|PACKAGE=proxmox-kernel-\$\(KVNAME\)|PACKAGE=proxmox-kernel-${CUSTOM_SUFFIX}-\$\(KVNAME\)|" Makefile
# sed -Ei "s|HDRPACKAGE=proxmox-headers-\$\(KVNAME\)|HDRPACKAGE=proxmox-headers-${CUSTOM_SUFFIX}-\$\(KVNAME\)|" Makefile
# sed -Ei "s|BUILD_DIR=proxmox-kernel-\$\(KERNEL_VER\)|BUILD_DIR=proxmox-kernel-${CUSTOM_SUFFIX}-\$\(KERNEL_VER\)|" Makefile

# Will not work if we already ran the String Replacement ...
# sed -Ei 's|PACKAGE=proxmox-kernel-\$\(KVNAME\)|PACKAGE=proxmox-kernel-${CUSTOM_SUFFIX}-$(KVNAME)|' Makefile
# sed -Ei 's|HDRPACKAGE=proxmox-headers-\$\(KVNAME\)|HDRPACKAGE=proxmox-headers-${CUSTOM_SUFFIX}-$(KVNAME)|' Makefile
# sed -Ei 's|BUILD_DIR=proxmox-kernel-\$\(KERNEL_VER\)|BUILD_DIR=proxmox-kernel-${CUSTOM_SUFFIX}-$(KERNEL_VER)|' Makefile

# Will not work if we already ran the String Replacement ...
sed -Ei "s|PACKAGE=proxmox-kernel-(.+)$|PACKAGE=proxmox-kernel-${CUSTOM_SUFFIX}-\$(KVNAME)|" Makefile
sed -Ei "s|HDRPACKAGE=proxmox-headers-(.+)$|HDRPACKAGE=proxmox-headers-${CUSTOM_SUFFIX}-\$(KVNAME)|" Makefile
sed -Ei "s|BUILD_DIR=proxmox-kernel-(.+)$|BUILD_DIR=proxmox-kernel-${CUSTOM_SUFFIX}-\$(KERNEL_VER)|" Makefile

# Copy Patches to Proxmox Patches Folder
for patch in ../patches/*.patch; do
    patchfilename=$(basename $patch)
    echo "Copy ../patches/${patchfilename} -> ./patches/kernel/${patchfilename}"
    cp ../patches/${patchfilename} patches/kernel/${patchfilename}
done

# Configure Custom Suffix
# scripts/config is in submodules/ubuntu-kernel/
# ./scripts/config --file "./config" --set-str CONFIG_LOCALVERSION "${CUSTOM_SUFFIX}"

# Clean Build Directory
make clean
# make distclean


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
