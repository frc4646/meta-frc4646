FILESEXTRAPATHS:prepend := "${THISDIR}/linux-jammy-nvidia-tegra-5.15/:"

#SRCBRANCH = "tegra-5.10-austin-rebase"
#SRCREV = "8f3cb4cfc09b761c599580fd8212fc37a9d69550"

#SRC_REPO = "github.com/realtimeroboticsgroup/linux.git;protocol=https;branch=${SRCBRANCH}"
#SRC_REPO = "file:///home/austin/local/linux-tegra-5.10/.git;protocol=file;branch=${SRCBRANCH}"

#SRC_URI += "file://config_preempt_rt.cfg"
#SRC_URI += "file://config_fan.cfg"
SRC_URI += "file://config_xfs.cfg"
#SRC_URI += "file://config_global_shutter_camera.cfg"
SRC_URI += "file://config_sctp.cfg"
SRC_URI += "file://uvc.cfg"
