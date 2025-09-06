do_install:append() {
    rm -f ${D}${libdir}/libnvparsers.so.${MAJVER}
    rm -f ${D}${libdir}/libnvparsers.so
}
