DEPENDS:append = "bash"

do_install:append () {
  sed -i 's#:${ROOT_HOME}:/bin/sh#:${ROOT_HOME}:/bin/bash#' ${D}${datadir}/base-passwd/passwd.master
}
