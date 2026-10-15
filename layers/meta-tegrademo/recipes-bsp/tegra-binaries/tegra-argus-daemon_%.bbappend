# The robot has no CSI cameras (the camera hardware is disabled in the device
# tree), so don't start nvargus-daemon.  The package stays installed because
# the camera libraries the multimedia API depends on need it.
SYSTEMD_AUTO_ENABLE:${PN} = "disable"
