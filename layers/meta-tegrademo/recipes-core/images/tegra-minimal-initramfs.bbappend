# These drivers are built into the kernel (config_boot_drivers.cfg), so there
# are no module packages to install.
PACKAGE_INSTALL:remove = "kernel-module-nvme kernel-module-pcie-tegra194 kernel-module-phy-tegra194-p2u"

# The init script brings eth0 up (tegra-minimal-init_1.0.bbappend), and r8169
# loads the PHY's firmware patch when it does.
PACKAGE_INSTALL += "linux-firmware-rtl8168"
