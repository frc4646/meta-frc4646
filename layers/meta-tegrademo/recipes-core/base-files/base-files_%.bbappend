FILESEXTRAPATHS:append := ":${THISDIR}/${PN}/"

hostname:pn-base-files = "orin-4646-1"

SRC_URI:append = " file://hosts"

PACKAGECONFIG = ""

do_install:append() {
    install -D -m0644 ${WORKDIR}/hosts ${D}${base_prefix}/etc/hosts
    sed -i 's#^/dev/root            /                    auto       defaults#/dev/root            /                    auto       rw,discard,noatime#' "${D}${sysconfdir}/fstab"
}

FILES:${PN}:append = "\
    ${base_prefix}/etc/hosts \
"
