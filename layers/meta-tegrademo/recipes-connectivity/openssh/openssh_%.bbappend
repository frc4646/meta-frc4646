FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

SRC_URI:append = " file://sshd \
                   file://0003-make-nocheck.patch \
"

do_install:append() {
    if [ "${@bb.utils.filter('DISTRO_FEATURES', 'pam', d)}" ]; then
        install -D -m 0644 ${UNPACKDIR}/sshd ${D}${sysconfdir}/pam.d/sshd
    fi
}

PARALLEL_MAKEINST = "-j1"
