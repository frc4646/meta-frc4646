FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://chrony.conf"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/chrony.conf ${D}${sysconfdir}
}
