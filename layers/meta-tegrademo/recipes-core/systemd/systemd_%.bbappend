# Make a journal log folder so we log persistant journal logs.
# Yocto expects someone to set this up (I think they want you to mount a folder),
# we've got one partition, might as well just do it here.  I suspect this is for
# RO Rootfs.
do_install:prepend() {
    mkdir -p ${D}${localstatedir}/log/journal
}
