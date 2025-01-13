FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

SRC_URI:append = " file://sshd"

do_install:append() {
    if [ "${@bb.utils.filter('DISTRO_FEATURES', 'pam', d)}" ]; then
        install -D -m 0644 ${WORKDIR}/sshd ${D}${sysconfdir}/pam.d/sshd
    fi
}
