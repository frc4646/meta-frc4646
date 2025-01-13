FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " \
        file://0001-l4tlauncher-disable-a-b-rootfs-validation.patch;patchdir=../edk2-nvidia \
"
