FILESEXTRAPATHS:prepend := "${THISDIR}/linux-yocto-6.18/:"

SRC_URI:append:tegra = " \
    file://config_xfs.cfg \
    file://config_sctp.cfg \
    file://uvc.cfg \
    file://config_rt_sched.cfg \
    file://config_no_yaffs.cfg \
    file://config_trim.cfg \
    file://config_boot_drivers.cfg \
    file://compressed.patch \
    file://0001-io_uring-wake-real-time-waiters-from-hard-interrupt-.patch \
"

# Fragments in SRC_URI are merged before KERNEL_FEATURES, and meta-tegra's
# features turn sound (cfg/tegra.cfg) and Bluetooth (jetson-devkit.scc) back
# on.  Listing the fragments as features as well merges them again after those.
KERNEL_FEATURES:append:tegra = " config_trim.cfg config_boot_drivers.cfg"

# Our own kernel-meta: features listed here are applied after meta-tegra's.
SRC_URI:append:tegra = " file://frc-kmeta;type=kmeta;destsuffix=frc-kmeta"
KERNEL_FEATURES:append:tegra = " features/frc/bpmp-debugfs-async.scc"
