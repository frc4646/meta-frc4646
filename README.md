# tegra-demo-distro

Reference/demo distribution for NVIDIA Jetson platforms
using Yocto Project tools and the [meta-tegra](https://github.com/OE4T/meta-tegra) BSP layer.

Metadata layers are brought in as git submodules:

| Layer Repo            | Branch         | Description                                         |
| --------------------- | ---------------|---------------------------------------------------- |
| openembedded-core     | wrynose        | OE-Core, pinned to Yocto 6.0.4                      |
| bitbake               | 2.18           | BitBake, pinned to Yocto 6.0.4                      |
| meta-tegra            | wrynose        | Pinned L4T R39.2.1 / JetPack 7.2.1                 |
| meta-tegra-community  | wrynose        | OE4T layer with additions from the community        |
| meta-openembedded     | wrynose        | OpenEmbedded layers                                 |
| meta-virtualization   | wrynose        | Virtualization layer                                |

Use the recorded submodule commits, not the moving branch tips:

```
git submodule update --init --recursive
```

## Usage

The upstream project has been modified to support AOS on the Jetson Nano 8GB SOM on a Seeed
studio J401. Confirm the carrier and module before selecting a machine;
`p3768-0000-p3767-0003` describes an 8GB production module on a P3768 carrier.
Build on Linux with a case-sensitive build filesystem. To build, run:

```
export MACHINE=p3768-0000-p3767-0003
. layers/oe-init-build-env build
bitbake demo-image-base
```

Note: this hasn't been tested yet with a fresh checkout, not everything might be captured yet.

To build for a devkit instead of a seed J401, use `MACHINE=jetson-orin-nano-devkit-nvme`.

The build needs about 200G in `build/tmp`.  To keep the download and shared
state caches elsewhere, create `build/conf/site.conf`:

```
DL_DIR = "/path/to/downloads"
SSTATE_DIR = "/path/to/sstate-cache"
```

## Root filesystem

The root filesystem is xfs, and the build makes it directly
(`classes-recipe/image_types_xfs.bbclass`, which runs `mkfs.xfs -p` on the
root filesystem directory).  The flash package in
`build/tmp/deploy/images/$MACHINE/demo-image-base-$MACHINE.rootfs.tegraflash-tar.zst`
is ready to flash as it is.

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

UEFI can't read xfs, so it never reads `/boot` on the root filesystem.
L4TLauncher boots the kernel, initrd and command line in the `A_kernel`
partition, which flashing writes from `boot.img`.  Changing the kernel means
reflashing.

## Flashing

Put the orin in recovery mode (hold RECOVERY while powering it on) and connect
it over USB.  `lsusb -d 0955:` on the flashing host shows `0955:7523` for this
module.  Then extract the flash package into an empty directory and run
`sudo ./initrd-flash` in it.

The flashing host needs `parted` and `udisks2` installed.  Without them the
flash stops at `partprobe` after the orin has shown up as a USB disk.

## Kernel

The image runs mainline `linux-yocto-rt` 6.18 with `PREEMPT_RT`, not NVIDIA's
downstream kernel.  This is set in
`layers/meta-tegrademo/conf/distro/include/tegrademo.inc`:

```
TEGRA_DEFAULT_KERNEL ?= "linux-yocto-rt"
```

`CONFIG_RT_GROUP_SCHED` has to stay off (`config_rt_sched.cfg`).  With it on,
nothing outside the root cgroup can use `SCHED_FIFO`, and AOS runs in
`aos.service`'s cgroup.

`config_trim.cfg` leaves out what the robot doesn't use: sound, Bluetooth,
Btrfs, JFFS2, NFS and IPVS.  Wi-Fi is left out of the image and the kernel.
The machine configuration also disables the audio hardware and the two empty
M.2 slots in the device tree (`DT_DISABLED_NODES`).

The kernel command line sets:

* `kpti=0`: KASLR otherwise forces kernel page table isolation on, which costs
  every system call, and the Cortex-A78 doesn't need it.
* `loglevel=4`: info-level messages stay off the serial console.  `dmesg` and
  the journal still have them.
* `efi=runtime`: `PREEMPT_RT` turns EFI runtime services off by default.
* `rootfstype=xfs`: without it, a root filesystem that fails to mount is
  retried as every other filesystem type.

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
  are disabled in the device tree (`DT_DISABLED_NODES`), and `nvargus-daemon`
  isn't started.  USB cameras use `uvcvideo`.

To see where boot time goes, add `initcall_debug log_buf_len=8M` to the
command line and look for the slowest `initcall` and `probe of` lines in
`dmesg`, then run `systemd-analyze critical-chain aos.service`.  The command
line is in the header of `boot.img`, which is all the `A_kernel` partition
holds, so a test kernel can be written there with `dd` without reflashing.

UEFI is NVIDIA's NVMe-only build (`TEGRA_MINIMAL_BOOT = "1"`): no network or
USB boot, no display, no shell, and no boot menu countdown.  To get into the
UEFI menu, flash with `TEGRA_MINIMAL_BOOT = "0"`.

To view the serial console:
```
python3 /usr/lib/python3/dist-packages/serial/tools/miniterm.py /dev/ttyUSB0 115200
```

# AOS compatibility before flashing

This image pins CUDA 13.2, OpenCV 4.13 and TensorRT 10.16.  AOS has to be
rebuilt against a sysroot exported from this image.  Missing
`libcudart.so.12` or `libopencv_*.so.411` on the Orin indicates old binaries;
reflashing alone does not fix them.

Export it with `compilers/buildify_yocto_image.py` in AOS, which turns the
built root filesystem into the `arm64_debian_sysroot` Bazel module.

TensorRT engines are tied to the TensorRT version which built them.  Rebuild
them on the Orin with `trtexec` after flashing, with nothing else using the GPU
while it runs.  The flags AOS's `yolo` needs are in the YOLO section of
`frc/vision/README.md` in AOS.

The 8GB module has little memory to spare with four cameras running.  Realtime
AOS processes lock every library they load into RAM, and the libraries in this
release are large (`libnvinfer.so` is 860 MB, `libcublasLt.so` 600 MB,
`libcufft.so` 290 MB), so a process should only link what it uses.

The UVC aliases below cover two alternative four-port hub layouts. Use one
layout at a time and verify `/dev/videoa` through `/dev/videod` against the
physical camera calibrations. Unknown USB layouts intentionally get no alias;
capture-device enumeration order is not a stable calibration identifier.

# UVC camera debugging

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
