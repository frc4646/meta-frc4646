DISTRO = "tegrademo"
DISTRO_NAME = "OE4Tegra Demonstration Distro"
DISTRO_VERSION_BASE = "6.0.2"
DISTRO_VERSION = "${DISTRO_VERSION_BASE}+snapshot-${METADATA_REVISION}"
DISTRO_CODENAME = "wrynose"

# VS Code's Remote SSH picks the glibc or musl build of its server from
# ldd and /etc/os-release, and without either falls back to Alpine's musl
# one, which can't run here.
ID_LIKE = "debian"

SDK_VENDOR = "-tdsdk"
SDK_VERSION = "${@d.getVar('DISTRO_VERSION').replace('snapshot-${METADATA_REVISION}', 'snapshot')}"
SDK_VERSION[vardepvalue] = "${SDK_VERSION}"

MAINTAINER = "OE4Tegra team <oe4tegra@madison.systems>"

TARGET_VENDOR = "-oe4t"

# New ${DISTRO}-<version> setting for sanity checks.
# Increment version number (and the corresponding
# setting int the template bblayers.conf.sample file)
# each time the layer settings are changed.
REQUIRED_TD_BBLAYERS_CONF_VERSION = "${DISTRO}-7"

LOCALCONF_VERSION = "2"

TD_DEFAULT_DISTRO_FEATURES = "opencl pam virtualization"
DISTRO_FEATURES ?= "${TD_DEFAULT_DISTRO_FEATURES}"

DISTRO_FEATURES_OPTED_OUT += "ptest vulkan"

# As of L4T R39, Jetson Orin platforms can use linux-yocto (6.18) instead of
# linux-noble-nvidia-tegra (6.8). Set TEGRA_DEFAULT_KERNEL to
# "linux-yocto" for the non-RT 6.18 kernel, or "linux-noble-nvidia-tegra" to
# go back to the NVIDIA kernel.
TEGRA_DEFAULT_KERNEL ?= "linux-yocto-rt"
PREFERRED_PROVIDER_virtual/kernel:tegra = "${TEGRA_DEFAULT_KERNEL}"
PREFERRED_VERSION_linux-yocto ?= "6.18%"
PREFERRED_VERSION_linux-yocto-rt ?= "6.18%"

# Both have two providers; name the ones the image has always had, so a new
# layer can't change which one it gets.  mDNS (<hostname>.local) is avahi,
# from the zeroconf distro feature.
PREFERRED_RPROVIDER_ssh = "openssh"
PREFERRED_RPROVIDER_libnss-mdns = "avahi-libnss-mdns"

SDK_NAME = "${DISTRO}-${TCLIBC}-${SDKMACHINE}-${IMAGE_BASENAME}-${TUNE_PKGARCH}-${MACHINE}"
SDKPATHINSTALL = "/opt/${DISTRO}/${SDK_VERSION}"

PACKAGE_CLASSES ?= "package_deb"

SANITY_TESTED_DISTROS ?= " \
            debian-12 \n \
            debian-13 \n \
            "

# Most NVIDIA-supplied services expect systemd
INIT_MANAGER = "systemd"

LICENSE_FLAGS_ACCEPTED += "commercial_faad2 commercial_x264"

USE_REDUNDANT_FLASH_LAYOUT_DEFAULT ?= "0"

# Build the root filesystem as xfs directly (see image_types_xfs.bbclass)
# and put that in the tegraflash package.
IMAGE_CLASSES += "image_types_xfs"
IMAGE_TEGRAFLASH_FS_TYPE:tegra = "xfs"
# The smallest APP partition the flash makes; it then fills the disk.  It has
# to hold the 64G XFS_IMAGE_SIZE.
ROOTFSPART_SIZE = "68719476736"

# No NFS, Bluetooth, mobile data or NFC on the robot.  This drops
# packagegroup-base's rpcbind, bluez, ofono and neard.  The kernel has no NFS
# or Bluetooth either (config_trim.cfg).
DISTRO_FEATURES:remove = "nfs bluetooth 3g nfc"
