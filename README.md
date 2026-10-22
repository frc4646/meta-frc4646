# tegra-demo-distro

Reference/demo distribution for NVIDIA Jetson platforms
using Yocto Project tools and the [meta-tegra](https://github.com/OE4T/meta-tegra) BSP layer.

Metadata layers are brought in as git submodules:

| Layer Repo            | Branch         | Description                                                       |
| --------------------- | ---------------|------------------------------------------------------------------ |
| openembedded-core     | wrynose        | OE-Core (Yocto 6.0) — replaces the deprecated poky combo-layer     |
| bitbake               | master         | BitBake (no codename branches; tracks master)                     |
| meta-yocto            | wrynose        | meta-poky / meta-yocto-bsp (formerly bundled in poky)             |
| meta-tegra            | wrynose        | L4T BSP layer - JetPack 7.2 / rel-39.2                           |
| meta-tegra-community  | wrynose        | OE4T layer with additions from the community                      |
| meta-openembedded     | wrynose        | OpenEmbedded layers                                               |
| meta-virtualization   | wrynose        | Virtualization layer for docker support                           |
| meta-clang            | wrynose        | Clang/LLVM toolchain layer                                         |

## Supported hardware (MACHINE targets)

The same `demo-image-base` recipe builds for three distinct Jetson Orin Nano targets. They are not interchangeable — pick the MACHINE that matches your physical hardware.

| MACHINE                                                        | Hardware                                                                 | SOM SKU      | Carrier | Rootfs boot |
| ------------------------------------------------------------- | ------------------------------------------------------------------------ | ------------ | ------- | ---------- |
| `p3768-0000-p3767-0003`                                       | Seeed Studio J401 + NVIDIA Jetson Orin Nano 8GB SOM (the FRC target)     | `P3767-0003` | `P3768-0000` | NVMe   |
| `jetson-orin-nano-devkit-nvme`                                | NVIDIA Jetson Orin Nano devkit (the ~$499 kit box, *not* the J401)       | `0005` (devkit SOM, set by `orin-nano.inc`) | NVIDIA devkit carrier | NVMe  |
| `jetson-orin-nano-devkit`                                     | NVIDIA Jetson Orin Nano devkit with SD-card rootfs (rarely used here)    | devkit SOM | NVIDIA devkit carrier | SD card |

Notes:

- The Seeed **J401** is the NVIDIA **`P3768-0000`** reference carrier (Seeed is an NVIDIA design partner). The name `p3768-0000-p3767-0003` encodes that mapping.
- `jetson-orin-nano-devkit-nvme` looks J401-like but targets the NVIDIA devkit carrier; its `orin-nano.inc` defaults `TEGRA_BOARDSKU = "0005"` (devkit SOM). `p3768-0000-p3767-0003` exists to override that to `"0003"` (the J401 production SOM) — building the wrong one fails to flash or boot on the J401.

## Usage

The upstream project has been modified to support AOS on the Jetson Orin Nano 8GB SOM on a Seeed studio J401.  
To build, run:

```
. setup-env --machine p3768-0000-p3767-0003 build
bitbake demo-image-base && ../to_xfs.py tmp/deploy/images/p3768-0000-p3767-0003/demo-image-base-p3768-0000-p3767-0003.rootfs.tegraflash-tar.gz demo-image-base-p3768-0000-p3767-0003.rootfs.tegraflash-tar.zst
```

Note: this hasn't been tested yet with a fresh checkout, not everything might be captured yet.

`to_xfs.py` takes the build's ext4-based `.tegraflash-tar.gz` tarball as input and writes
an equivalent tarball whose internal rootfs is XFS (so it can be flashed onto an XFS-formatted
root partition). The second argument is the *output* path.

To flash, extract the image, then run `sudo ./initrd-flash` with the orin in bootloader mode, connected over USB.

To build for the NVIDIA Orin Nano devkit (the kit box, not the Seeed J401) instead, run:
```
. setup-env --machine jetson-orin-nano-devkit-nvme build
bitbake demo-image-base && ../to_xfs.py tmp/deploy/images/jetson-orin-nano-devkit-nvme/demo-image-base-jetson-orin-nano-devkit-nvme.rootfs.tegraflash-tar.gz demo-image-base-jetson-orin-nano-devkit-nvme.rootfs.tegraflash-tar.zst
```


To view the serial console:
```
python3 /usr/lib/python3/dist-packages/serial/tools/miniterm.py /dev/ttyUSB0 115200
```

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
modprobe uvcvideo quirks=128
```

`dmesg` will spit out frame statistics, including bandwidth usage.

## Global-shutter camera (IMX477)

The walnascar `config_global_shutter_camera.cfg` enabled `CONFIG_NV_VIDEO_IMX477` (NVIDIA's out-of-tree tegra camera driver). That symbol does not exist in the 6.8 noble kernel — NVIDIA dropped the tegra camera driver from the upstream-noble rebase. The fragment is therefore dropped; if NVIDIA ships a 6.8-compatible IMX477 driver it can be re-added as an out-of-tree module.
