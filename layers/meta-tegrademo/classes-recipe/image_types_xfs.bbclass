# An "xfs" image type: an XFS filesystem image populated directly from the
# root filesystem directory by mkfs.xfs (xfsprogs 6.17 and newer), so no root
# privileges, loop devices or mounts are needed.
#
# The image is created at a fixed, small size; grow-rootfs.service grows it to
# fill the partition on first boot.

IMAGE_TYPES += "xfs"

# grow-rootfs.service only adds groups of the size mkfs picked, and keeps the
# log it made, so mkfs here has to pick what it would for the 1T NVMe: with
# su=128k, 32 groups of 32G and a 512M log.  An image needs at least 2 groups,
# hence 64G.
#
# mkfs.xfs -p puts each file's data next to its inode, so the groups holding
# big directories (CUDA, TensorRT) can fill up completely.  A full group has
# no room for the reserve XFS keeps so its indexes can always grow, and the
# kernel warns "ENOSPC reserving per-AG metadata pool, log recovery may fail"
# at every mount.  Growing the filesystem doesn't help, since it never frees
# space in an existing group.  With 2 groups of 32G, each kept over 27G free.
# Unused space is stored as holes, so the image size costs nothing to flash.
XFS_IMAGE_SIZE ?= "64G"
XFS_MKFS_OPTIONS ?= "-d su=128k,sw=1,agsize=32g -l size=512m -L rootfs"

do_image_xfs[depends] += "xfsprogs-native:do_populate_sysroot"

IMAGE_CMD:xfs () {
    # mkfs.xfs only takes a directory for -p from xfsprogs 6.17; older
    # versions take a protofile there instead.
    version=$(mkfs.xfs -V | sed -n 's/^mkfs.xfs version //p')
    if [ "$(printf '%s\n' 6.17 "$version" | sort -V | head -n 1)" != 6.17 ]; then
        bbfatal "mkfs.xfs $version can't make a filesystem from a directory; xfsprogs 6.17 or newer is needed"
    fi
    rm -f ${IMGDEPLOYDIR}/${IMAGE_NAME}.xfs
    truncate -s ${XFS_IMAGE_SIZE} ${IMGDEPLOYDIR}/${IMAGE_NAME}.xfs
    mkfs.xfs ${XFS_MKFS_OPTIONS} -p ${IMAGE_ROOTFS} ${IMGDEPLOYDIR}/${IMAGE_NAME}.xfs
    # mkfs.xfs writes one record at the start of the log and leaves the rest
    # of it zero.  The flash package stores zeros as holes, and make-sdcard
    # writes the partition with bmaptool, which skips holes, so the rest of the
    # log keeps whatever the disk held before.  If that was an XFS log, the
    # kernel can't find the log head and the root filesystem won't mount.
    # Stamp every log block with a record instead, so there is nothing to skip.
    xfs_db -x -c "logformat -c 2" ${IMGDEPLOYDIR}/${IMAGE_NAME}.xfs
}
