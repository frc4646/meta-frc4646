FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

hostname:pn-base-files = "orin-6767-1"

SRC_URI:append = " file://hosts"

PACKAGECONFIG = ""

do_install:append() {
    install -D -m0644 ${WORKDIR}/hosts ${D}${base_prefix}/etc/hosts
}

FILES:${PN}:append = "\
    ${base_prefix}/etc/hosts \
"
