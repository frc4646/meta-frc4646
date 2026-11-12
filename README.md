# meta-frc4646

The image AOS runs on: an Orin Nano 8GB on a Seeed Studio J401 carrier, with
a mainline `PREEMPT_RT` kernel.  It is built with Yocto Project tools and the
[meta-tegra](https://github.com/OE4T/meta-tegra) BSP layer, and started from
the [tegra-demo-distro](https://github.com/OE4T/tegra-demo-distro) reference
distribution.

* [docs/details.md](docs/details.md): how the image is put together (root
  filesystem, kernel, boot time, UEFI, camera debugging).
* [docs/realtime.md](docs/realtime.md): the real-time configuration
  (scheduling priorities, interrupts, networking, kernel patches and
  measuring latency).

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

## Building

Confirm the carrier and module before selecting a machine;
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

The flash package is
`build/tmp/deploy/images/$MACHINE/demo-image-base-$MACHINE.rootfs.tegraflash-tar.zst`.

## Flashing

Put the orin in recovery mode (hold RECOVERY while powering it on) and connect
it over USB.  `lsusb -d 0955:` on the flashing host shows `0955:7523` for this
module.  Then extract the flash package into an empty directory and run
`sudo ./initrd-flash` in it.

The flashing host needs `parted` and `udisks2` installed.  Without them the
flash stops at `partprobe` after the orin has shown up as a USB disk.

Changing the kernel means reflashing; see
[docs/details.md](docs/details.md#booting).

To view the serial console:
```
python3 /usr/lib/python3/dist-packages/serial/tools/miniterm.py /dev/ttyUSB0 115200
```

## AOS compatibility

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

## Cameras

`camera.rules` names the UVC cameras `/dev/videoa` through `/dev/videod` by
USB port, for two alternative four-port hub layouts.  Use one layout at a time
and verify the names against the physical camera calibrations.  Unknown USB
layouts intentionally get no name; capture-device enumeration order is not a
stable calibration identifier.

For UVC driver debugging, see
[docs/details.md](docs/details.md#uvc-camera-debugging).
