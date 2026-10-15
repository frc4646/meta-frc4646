FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI += "file://early-eth0.sh"

# The root disk's drivers are built into the kernel (config_boot_drivers.cfg),
# so drop the loop which ran modprobe for every device in /sys.  It took 1.3
# seconds, and udev loads the same modules from the root filesystem anyway.
# In its place, bring eth0 up.
do_install:append() {
    sed -i -e '/^find \/sys -name modalias/,/^done$/d' \
        -e "/^modprobe -v nvme$/r ${UNPACKDIR}/early-eth0.sh" \
        ${D}/init
    if grep -q modalias ${D}/init || ! grep -q "ip link set eth0 up" ${D}/init; then
        bbfatal "Failed to edit the initrd's init script"
    fi
}
