FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

hostname:pn-base-files = "orin-1868-1"

SRC_URI:append = " file://hosts"

PACKAGECONFIG = ""

do_install:append() {
    install -D -m0644 ${WORKDIR}/sources/hosts ${D}${base_prefix}/etc/hosts
    sed -i 's#^/dev/root            /                    auto       defaults#/dev/root            /                    auto       rw,discard,noatime#' "${D}${sysconfdir}/fstab"
}

FILES:${PN}:append = "\
    ${base_prefix}/etc/hosts \
"
