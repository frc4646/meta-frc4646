FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Publish orin-N.local and orin.local as well as orin-TEAM-N.local.  They are
# aliases for the Orin's own address, which avahi only accepts without the
# reverse records it already publishes for the hostname.
SRC_URI:append = " \
    file://0001-avahi-daemon-don-t-publish-reverse-records-for-stati.patch \
    file://hosts \
"

do_install:append() {
    install -m 0644 ${UNPACKDIR}/hosts ${D}${sysconfdir}/avahi/hosts
}
