SUMMARY = "Adds the pi user"
SECTION = "conf"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"
PR = "r0"

DOTFILES_REF="v0.1"

SRCREV="fa97e077944d36e320201a2627cc6a75e4f1bceb"
SRC_URI:append = " file://home/pi/.ssh/authorized_keys"
SRC_URI:append = " file://etc/security/limits.d/rt.conf"
SRC_URI:append = " git://github.com/AustinSchuh/.dotfiles.git;protocol=https;branch=main;name=dotfiles"

do_install[network] = '1'

PACKAGES =+ "${PN}-pi"

S = "${WORKDIR}/sources"
UNPACKDIR = "${S}"

inherit useradd

GROUPADD_PARAM:${PN} = "sudo; video; system-journal; dialout; adm"

USERADD_PACKAGES = "${PN}"

# user: pi, password: raspberry
USERADD_PARAM:${PN} = "-G sudo,video,system-journal,dialout,adm -m -p \"\\\$y\\\$j9T\\\$85lzhdky63CTj.two7Zj20\\\$pVY53UR0VebErMlm8peyrEjmxeiRw/rfXfx..9.xet1\" -r -s /bin/bash pi"


install_content() {
    set -x
    install -D -m"$1" "$2" "${D}${base_prefix}/$2"
    chown "$3" "${D}${base_prefix}/$2"
}

do_install() {
    set -x
    mkdir -p -m755 ${D}${base_prefix}/home/pi/.ssh
    mkdir -p -m755 ${D}${base_prefix}/home/pi/bin/logs

    install -D -m0600 home/pi/.ssh/authorized_keys ${D}${base_prefix}/home/pi/.ssh/authorized_keys
    chown pi:pi ${D}${base_prefix}/home/pi/.ssh/authorized_keys

    # Install dotfiles.
    mkdir -p ${D}${base_prefix}/home/pi/.dotfiles
    rsync --recursive --verbose --exclude '.git' ${WORKDIR}/sources/git/ ${D}${base_prefix}/home/pi/
    chown -R pi:pi ${D}${base_prefix}/home/pi/

    # Now setup vundle for vim.
    echo "" | HOME=${D}${base_prefix}/home/pi/ /usr/bin/vim -u ${D}${base_prefix}/home/pi/.vimrc -c PluginInstall -c qall | tee /dev/null
    rm ${D}${base_prefix}/home/pi/.viminfo
    chown -R pi:pi ${D}${base_prefix}/home/pi/

    # Do it for root too...
    mkdir -p ${D}${base_prefix}${ROOT_HOME}/.dotfiles
    rsync --recursive --verbose --exclude '.git' ${WORKDIR}/sources/git/ ${D}${base_prefix}${ROOT_HOME}/
    chown -R root:root ${D}${base_prefix}${ROOT_HOME}/
    echo "" | HOME=${D}${base_prefix}${ROOT_HOME}/ /usr/bin/vim -u ${D}${base_prefix}${ROOT_HOME}/.vimrc -c PluginInstall -c qall | tee /dev/null
    rm ${D}${base_prefix}${ROOT_HOME}/.viminfo
    chown -R root:root ${D}${base_prefix}${ROOT_HOME}


    mkdir -p ${D}${sysconfdir}/sudoers.d/

    echo "pi ALL=(ALL) NOPASSWD: ALL" > ${D}${sysconfdir}/sudoers.d/001_pi

    install_content 0644 "etc/security/limits.d/rt.conf" "root:root"

    mkdir -p -m755 ${D}${base_prefix}/etc/bash_completion.d/
    ln -s /usr/share/bash-completion/completions/git-prompt.sh ${D}${base_prefix}/etc/bash_completion.d/git-prompt
    chown -h root:root ${D}${base_prefix}/etc/bash_completion.d/git-prompt
}

RDEPENDS:${PN} += " git bash vim git-bash-completion perl"
DEPENDS += " git bash vim rsync-native"

FILES:${PN} = "${base_prefix}/home/pi"
FILES:${PN}:append = " ${base_prefix}${ROOT_HOME}"
FILES:${PN}:append = " ${base_prefix}/etc/sudoers.d/001_pi"
FILES:${PN}:append = " ${base_prefix}/etc/security/limits.d/rt.conf"
FILES:${PN}:append = " ${base_prefix}/etc/bash_completion.d/git-prompt"
