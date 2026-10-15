FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://nv-load-gpu-modules.service"

# NVIDIA loads the GPU and display drivers from systemd-modules-load.service
# (nvgpu and nvmap through KERNEL_MODULE_AUTOLOAD, the display drivers through
# a drop-in).  nvgpu takes most of a second to load, and systemd-networkd is
# ordered after systemd-sysctl, which is ordered after
# systemd-modules-load, so the network waited for the GPU.  Load nvgpu and
# nvmap from their own service instead, still before sysinit.target, so that
# everything which used to find the GPU loaded still does, and don't load
# the display drivers at all.  KERNEL_MODULE_AUTOLOAD drops nvgpu and nvmap in
# the machine configuration.
do_install:append() {
    rm ${D}${sysconfdir}/systemd/system/systemd-modules-load.service.d/nv-load-display-modules.conf
    rmdir ${D}${sysconfdir}/systemd/system/systemd-modules-load.service.d
    install -m 0644 -D -t ${D}${systemd_system_unitdir} ${UNPACKDIR}/nv-load-gpu-modules.service
    install -d ${D}${sysconfdir}/systemd/system/sysinit.target.wants
    ln -sf ${systemd_system_unitdir}/nv-load-gpu-modules.service \
        ${D}${sysconfdir}/systemd/system/sysinit.target.wants/nv-load-gpu-modules.service
}

FILES:${PN}-display-driver += " \
    ${systemd_system_unitdir}/nv-load-gpu-modules.service \
    ${sysconfdir}/systemd/system/sysinit.target.wants/nv-load-gpu-modules.service \
"
