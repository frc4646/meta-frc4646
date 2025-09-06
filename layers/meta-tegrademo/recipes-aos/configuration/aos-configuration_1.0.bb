DESCRIPTION = "Dotfiles"
SECTION = "conf"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
PR = "r0"

DOTFILES_REF="5f61e185231919b89233b841841ef30c37bc63be"

SRC_URI:append = " file://contents/"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit systemd

SYSTEMD_AUTO_ENABLE:${PN} = "enable"
SYSTEMD_SERVICE:${PN} = "grow-rootfs.service jetson-clocks.service aos.service aos-chrt.service hwclock.service"

ROOT = "${D}${base_prefix}"

install_content() {
    install -D -m"$1" "contents/$2" "${ROOT}/$2"
    chown "$3" "${ROOT}/$2"
}

do_install() {
    mkdir -p -m700 ${ROOT}${ROOT_HOME}/bin
    chown root:root ${ROOT}${ROOT_HOME}/bin

    install -D -m0700 contents/root/bin/trace.sh ${ROOT}${ROOT_HOME}/bin/trace.sh
    install_content 0500 "root/bin/change_hostname.sh" "root:root"
    install_content 0500 "root/bin/chrt.sh" "root:root"

    install_content 0644 "etc/sysctl.d/sctp.conf" "root:root"
    install_content 0555 "etc/bash_completion.d/aos_dump_autocomplete" "root:root"
    install_content 0644 "etc/modprobe.d/can.conf" "root:root"
    install_content 0644 "etc/modprobe.d/uvc.conf" "root:root"
    install_content 0644 "etc/udev/rules.d/can.rules" "root:root"
    install_content 0644 "etc/udev/rules.d/camera.rules" "root:root"
    install_content 0644 "etc/systemd/network/80-cana.network" "root:root"
    install_content 0644 "etc/systemd/network/80-canb.network" "root:root"
    install_content 0644 "etc/systemd/network/80-canc.network" "root:root"
    install_content 0644 "etc/systemd/system/usb-mount@.service" "root:root"
    install_content 0644 "etc/systemd/system/grow-rootfs.service" "root:root"
    install_content 0644 "etc/systemd/system/aos.service" "root:root"
    install_content 0644 "etc/systemd/system/aos-chrt.service" "root:root"
    install_content 0644 "etc/systemd/system/jetson-clocks.service" "root:root"

    # Setup hwclock
    install_content 0644 "etc/systemd/system/hwclock.service" "root:root"
}

RDEPENDS:${PN} += " git"
RDEPENDS:${PN} += " bash-completion git-bash-completion"
RDEPENDS:${PN} += " bash"

FILES:${PN} = "${base_prefix}${ROOT_HOME}/"
FILES:${PN}:append = " ${base_prefix}${ROOT_HOME}/bin/"
FILES:${PN}:append = " ${base_prefix}/etc/sysctl.d/sctp.conf"
FILES:${PN}:append = " ${base_prefix}/etc/bash_completion.d/aos_dump_autocomplete"
FILES:${PN}:append = " ${base_prefix}/etc/modprobe.d/can.conf"
FILES:${PN}:append = " ${base_prefix}/etc/modprobe.d/uvc.conf"
FILES:${PN}:append = " ${base_prefix}/etc/udev/rules.d/can.rules"
FILES:${PN}:append = " ${base_prefix}/etc/udev/rules.d/camera.rules"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/network/80-cana.network"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/network/80-canb.network"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/network/80-canc.network"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/usb-mount@.service"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/grow-rootfs.service"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/aos.service"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/aos-chrt.service"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/jetson-clocks.service"
FILES:${PN}:append = " ${base_prefix}/etc/systemd/system/hwclock.service"
