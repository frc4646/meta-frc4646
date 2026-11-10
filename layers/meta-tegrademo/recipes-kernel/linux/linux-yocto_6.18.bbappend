FILESEXTRAPATHS:prepend := "${THISDIR}/linux-yocto-6.18/:"

SRC_URI:append:tegra = " \
    file://config_xfs.cfg \
    file://config_sctp.cfg \
    file://uvc.cfg \
    file://config_rt_sched.cfg \
    file://config_no_yaffs.cfg \
    file://config_trim.cfg \
    file://config_boot_drivers.cfg \
    file://config_btf.cfg \
    file://config_tracers.cfg \
    file://compressed.patch \
    file://0001-io_uring-wait-wake-real-time-waiters-from-hard-interrupt-context.patch \
    file://0002-io_uring-don-t-trust-an-earlier-task_work-add-to-wak.patch \
    file://0003-io_uring-bound-the-number-of-released-rings-waiting-.patch \
    file://0004-io_uring-futex-return-a-wait-s-data-to-the-cache-whe.patch \
"

# Fragments in SRC_URI are merged before KERNEL_FEATURES, and meta-tegra's
# features turn sound (cfg/tegra.cfg) and Bluetooth (jetson-devkit.scc) back
# on.  Listing the fragments as features as well merges them again after those.
KERNEL_FEATURES:append:tegra = " config_trim.cfg config_boot_drivers.cfg config_btf.cfg config_tracers.cfg"

# Our own kernel-meta: features listed here are applied after meta-tegra's.
SRC_URI:append:tegra = " file://frc-kmeta;type=kmeta;destsuffix=frc-kmeta"
KERNEL_FEATURES:append:tegra = " features/frc/bpmp-debugfs-async.scc features/frc/tegra186-timer-kexec.scc"

# config_btf.cfg: CONFIG_DEBUG_INFO_BTF depends on CONFIG_PAHOLE_VERSION, which
# Kconfig reads from pahole.  linux-yocto.inc makes pahole available and stops
# passing PAHOLE=false to make only when KERNEL_DEBUG is "True".
KERNEL_DEBUG = "True"

# Newer than the 6.18.52 oe-core 6.0.4 has: 6.18.59 is the newest
# linux-yocto 6.18.  meta-tegra's patch queue moves with it, to the one
# refreshed against 6.18.59.
LINUX_VERSION = "6.18.59"
SRCREV_machine = "0aa9c16e54e9a318d97bae25e0082d7807186232"
SRCREV_meta = "cf1eb35154969907fb08e980fe6d1881c97d6a97"
SRCREV_tegrameta = "1bf0077574169c8724f994a2088221212e88b24f"
