# Sets status = "disabled" on each node in DT_DISABLED_NODES, in the device
# trees the machine boots with.  UEFI uses the same device tree, so it skips
# those nodes too.
DT_DISABLED_NODES ??= ""

disable_dt_nodes() {
    for dtb in ${KERNEL_DEVICETREE}; do
        dtb=$(basename $dtb)
        for node in ${DT_DISABLED_NODES}; do
            fdtput -t s ${B}/$dtb $node status disabled
        done
    done
}
# do_compile is python, so this can't be appended to it.  It has to run
# before do_sign_dtbs.
do_compile[postfuncs] += "disable_dt_nodes"
