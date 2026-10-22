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

# Stay on 6.18.39, the kernel the real-time measurements were made on.  The
# io_uring patches are written against it, and some of the 6.18.52 that
# oe-core 6.0.4 moved to doesn't take them.  meta-tegra's patch queue goes
# back with it: the newer one is refreshed against 6.18.44.
LINUX_VERSION = "6.18.39"
SRCREV_machine = "9eb7db1359675f27707b030ba228f381c10cd53e"
SRCREV_meta = "2f71b0a288c307062fc60948ac793d8d51c685e2"
SRCREV_tegrameta = "a78c980f4c0f9aec1ccc9a176fcdd5516be2faa5"
