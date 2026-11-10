# Image details

How the image is put together.  The real-time configuration is in
[realtime.md](realtime.md).

## Root filesystem

The root filesystem is xfs, and the build makes it directly
(`classes-recipe/image_types_xfs.bbclass`, which runs `mkfs.xfs -p` on the
root filesystem directory).  The flash package is ready to flash as it is.

`grow-rootfs.service` grows the filesystem to fill the partition when the
orin boots, but only by adding allocation groups of the size the image has,
and it keeps the image's log.  `XFS_MKFS_OPTIONS` pins both to what `mkfs.xfs`
picks for the 1T NVMe (32G groups, a 512M log), and `XFS_IMAGE_SIZE` is 64G,
the 2 groups an image needs.

`mkfs.xfs` fills its allocation groups unevenly, and a full one makes the
kernel warn "ENOSPC reserving per-AG metadata pool" at every mount.  Growing
the filesystem can't free space in a full group, so every group in the image
has to have room; check with `xfs_db -r -c "agf N" -c "p freeblks"` after
changing what goes in the image.

## Booting

UEFI can't read xfs, so it never reads `/boot` on the root filesystem.
L4TLauncher boots the kernel, initrd and command line in the `A_kernel`
partition, which flashing writes from `boot.img`.  Changing the kernel means
reflashing.

UEFI is NVIDIA's NVMe-only build (`TEGRA_MINIMAL_BOOT = "1"`): no network or
USB boot, no display, no shell, and no boot menu countdown.  To get into the
UEFI menu, flash with `TEGRA_MINIMAL_BOOT = "0"`.

## Kernel

The image runs mainline `linux-yocto-rt` 6.18 with `PREEMPT_RT`, not NVIDIA's
downstream kernel.  This is set in
`layers/meta-tegrademo/conf/distro/include/tegrademo.inc`:

```
TEGRA_DEFAULT_KERNEL ?= "linux-yocto-rt"
```

`config_trim.cfg` leaves out what the robot doesn't use: sound, Bluetooth,
Btrfs, JFFS2, NFS and IPVS.  Wi-Fi is left out of the image and the kernel.
The machine configuration (`conf/machine/include/frc-orin-nano.inc`) also
disables the audio, display and CSI camera hardware and the two empty M.2
slots in the device tree (`DT_DISABLED_NODES`).

The kernel command line sets:

* `loglevel=4`: info-level messages stay off the serial console.  `dmesg` and
  the journal still have them.
* `efi=runtime`: `PREEMPT_RT` turns EFI runtime services off by default, and
  the boot slot tools need the EFI variables.
* `rootfstype=xfs`: without it, a root filesystem that fails to mount is
  retried as every other filesystem type, and yaffs crashes the kernel.

The options that matter for latency are in [realtime.md](realtime.md#kernel).

## Boot time

The orin reaches `network-online.target` (which `aos.service` waits for)
about 7.5 seconds after the kernel starts.  To keep it there:

* `frc-kmeta/features/frc/bpmp-debugfs-async.scc` builds the BPMP's debugfs
  tree in the background.  It took 5.2 seconds, and every device which needs
  the BPMP for clocks or power waited for it.
* `config_boot_drivers.cfg` builds PCIe, NVMe and the Ethernet driver into the
  kernel, and `driver_async_probe=tegra194-pcie` trains the PCIe links in
  parallel.  The initrd no longer runs `modprobe` for every device, and brings
  eth0 up so Gigabit autonegotiation (3 seconds) overlaps the rest of boot.
* `nv-load-gpu-modules.service` loads nvgpu instead of
  `systemd-modules-load.service`, which networkd waits for.  The display
  drivers aren't loaded at all.
* The display, audio and CSI camera hardware, and the two empty M.2 slots,
  are disabled in the device tree, and `nvargus-daemon` isn't started.  USB
  cameras use `uvcvideo`.

To see where boot time goes, add `initcall_debug log_buf_len=8M` to the
command line and look for the slowest `initcall` and `probe of` lines in
`dmesg`, then run `systemd-analyze critical-chain aos.service`.  The command
line is in the header of `boot.img`, which is all the `A_kernel` partition
holds, so a test kernel can be written there with `dd` without reflashing.

## UVC camera debugging

To turn on all debugging in dmesg:

```
echo 0xffff | sudo tee /sys/module/uvcvideo/parameters/trace
```

Set it back to 0 to turn it off.

```
echo 0 | sudo tee /sys/module/uvcvideo/parameters/trace
```

To turn quirks on to fix bandwidth calcs:

```
rmmod uvcvideo
modprobe uvcvideo quirks=128 bandwidth_quirk_divisor=16
```

`dmesg` will spit out frame statistics, including bandwidth usage.

The image's `uvc.conf` sets these parameters. The divisor is a camera-specific
bandwidth workaround, not evidence that four simultaneous streams will fit.
Check all four streams at the configured resolution and frame rate. The
divisor is read-only after module load; zero is treated as one to avoid a
kernel divide-by-zero.
