FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

SRC_URI:append = " file://eth0.network"
SRC_URI:append = " file://logind.conf"

# Disable dhcp by default.
PACKAGECONFIG = ""

do_install:append() {
    install -D -m0644 ${WORKDIR}/eth0.network ${D}${base_prefix}/etc/systemd/network/eth0.network
    install -D -m0644 ${WORKDIR}/logind.conf ${D}${systemd_unitdir}/logind.conf.d/00-${PN}.conf
}

FILES:${PN}:append = "\
    ${base_prefix}/etc/systemd/network/ \
    ${base_prefix}/etc/systemd/logind.conf \
"
