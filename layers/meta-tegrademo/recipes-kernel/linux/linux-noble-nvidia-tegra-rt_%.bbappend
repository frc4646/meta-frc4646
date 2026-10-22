# Named -rt (not the plain linux-noble-nvidia-tegra_%.bbappend) so the
# wildcard matches the -rt recipe variant that local.conf.sample pins.
FILESEXTRAPATHS:prepend := "${THISDIR}/linux-noble-nvidia-tegra-6.8/:"

SRC_URI += "file://config_xfs.cfg"
SRC_URI:append:tegra = " file://compressed.patch"
