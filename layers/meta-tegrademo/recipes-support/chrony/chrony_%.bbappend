FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://chrony.conf"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/chrony.conf ${D}${sysconfdir}
}

# chrony keeps the clock synchronized, so mask systemd-timesyncd, which
# systemd enables by default.  Two of them would fight over the clock.
do_install:append() {
    install -d ${D}${sysconfdir}/systemd/system
    ln -sf /dev/null ${D}${sysconfdir}/systemd/system/systemd-timesyncd.service
}
FILES:${PN} += "${sysconfdir}/systemd/system/systemd-timesyncd.service"
