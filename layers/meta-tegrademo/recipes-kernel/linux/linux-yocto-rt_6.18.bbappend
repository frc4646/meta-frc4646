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
    file://config_preempt_rt.cfg \
    file://compressed.patch \
    file://0001-io_uring-wake-real-time-waiters-from-hard-interrupt-.patch \
    file://0002-io_uring-don-t-trust-an-earlier-task_work-add-to-wak.patch \
    file://0003-io_uring-bound-the-number-of-released-rings-waiting-.patch \
    file://0004-io_uring-futex-return-a-wait-s-data-to-the-cache-whe.patch \
    file://0009-r8169-re-enable-interrupt-source-RxOverflow.patch \
    file://0010-net-run-the-NAPI-deferred-poll-timer-in-hard-IRQ-context.patch \
    file://0011-net-sched-boost-a-preempted-qdisc-owner-on-PREEMPT_RT.patch \
"

# Fragments in SRC_URI are merged before KERNEL_FEATURES, and the features
# turn sound (cfg/tegra.cfg), Bluetooth (jetson-devkit.scc) and KVM back on.
# Listing the fragments as features as well merges them again after those.
KERNEL_FEATURES:append:tegra = " config_trim.cfg config_boot_drivers.cfg config_btf.cfg config_preempt_rt.cfg config_tracers.cfg"

# Our own kernel-meta: features listed here are applied after meta-tegra's.
SRC_URI:append:tegra = " file://frc-kmeta;type=kmeta;destsuffix=frc-kmeta"
KERNEL_FEATURES:append:tegra = " features/frc/bpmp-debugfs-async.scc features/frc/tegra186-timer-kexec.scc"

# config_btf.cfg: CONFIG_DEBUG_INFO_BTF depends on CONFIG_PAHOLE_VERSION, which
# Kconfig reads from pahole.  linux-yocto.inc makes pahole available and stops
# passing PAHOLE=false to make only when KERNEL_DEBUG is "True".
KERNEL_DEBUG = "True"

# Stay on 6.18.39, the kernel the real-time measurements were made on.  The
# io_uring patches are written against it, and some of the 6.18.52 that
# oe-core 6.0.4 moved to doesn't take them.  meta-tegra's patch queue goes
# back with it: the newer one is refreshed against 6.18.44.
LINUX_VERSION = "6.18.39"
SRCREV_machine = "56572c42354027a50e261f16fe13b057604873e7"
SRCREV_meta = "2f71b0a288c307062fc60948ac793d8d51c685e2"
SRCREV_tegrameta = "a78c980f4c0f9aec1ccc9a176fcdd5516be2faa5"
