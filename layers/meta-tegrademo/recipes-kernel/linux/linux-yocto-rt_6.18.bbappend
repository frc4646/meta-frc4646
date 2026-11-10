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
    file://0001-io_uring-wait-wake-real-time-waiters-from-hard-interrupt-context.patch \
    file://0002-io_uring-don-t-trust-an-earlier-task_work-add-to-wak.patch \
    file://0003-io_uring-bound-the-number-of-released-rings-waiting-.patch \
    file://0004-io_uring-futex-return-a-wait-s-data-to-the-cache-whe.patch \
    file://0009-r8169-re-enable-interrupt-source-RxOverflow.patch \
    file://0010-net-run-the-NAPI-deferred-poll-timer-in-hard-IRQ-context.patch \
    file://0011-net-sched-boost-a-preempted-qdisc-owner-on-PREEMPT_RT.patch \
    file://0012-sctp-Track-runs-of-contiguous-fragments-in-reassembl.patch \
    file://0013-sctp-Tell-the-peer-about-the-unsent-rest-of-an-aband.patch \
    file://0014-sctp-Limit-how-much-is-queued-below-a-socket.patch \
    file://0015-sctp-Only-discard-the-skipped-messages-on-an-I-FORWA.patch \
    file://0016-sctp-Drop-late-fragments-of-skipped-messages.patch \
    file://0017-sctp-Only-abort-the-partial-delivery-a-FORWARD-TSN-s.patch \
    file://0018-sctp-Only-start-partial-delivery-when-the-message-ca.patch \
    file://0019-sctp-Deliver-the-lobby-first-when-partial-delivery-e.patch \
    file://0020-sctp-Hold-partial-delivery-pieces-until-there-s-pd_p.patch \
    file://0021-sctp-Build-large-messages-without-holding-the-socket.patch \
    file://0022-sctp-Restart-RTT-measurement-when-the-timed-chunk-is.patch \
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

# Newer than the 6.18.52 oe-core 6.0.4 has: 6.18.59 is the newest
# linux-yocto 6.18.  meta-tegra's patch queue moves with it, to the one
# refreshed against 6.18.59.
LINUX_VERSION = "6.18.59"
SRCREV_machine = "582762f4ac66e79c16b088b3fbb5a67a57a15d88"
SRCREV_meta = "cf1eb35154969907fb08e980fe6d1881c97d6a97"
SRCREV_tegrameta = "1bf0077574169c8724f994a2088221212e88b24f"
