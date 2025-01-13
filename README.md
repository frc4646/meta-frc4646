# tegra-demo-distro

Reference/demo distribution for NVIDIA Jetson platforms
using Yocto Project tools and the [meta-tegra](https://github.com/OE4T/meta-tegra) BSP layer.

Metadata layers are brought in as git submodules:

| Layer Repo            | Branch         | Description                                         |
| --------------------- | ---------------|---------------------------------------------------- |
| poky                  | scarthgap      | OE-Core from poky repo at yoctoproject.org          |
| meta-tegra            | scarthgap      | L4T BSP layer - L4T R36.4.0/JetPack 6.1             |
| meta-tegra-community  | scarthgap      | OE4T layer with additions from the community        |
| meta-openembedded     | scarthgap      | OpenEmbedded layers                                 |
| meta-virtualization   | scarthgap      | Virtualization layer for docker support             |

## Usage

The upstream project has been modified to support AOS on the Jetson Nano 8GB SOM on a Seeed
studio J401.  To build, run:

```
export MACHINE=jetson-orin-nano-som
. repos/poky/oe-init-build-env build
bitbake demo-image-base && ../to_xfs.py tmp/deploy/images/jetson-orin-nano-som/demo-image-base-jetson-orin-nano-som.rootfs.tegraflash.tar.gz demo-image-base-jetson-orin-nano-som.rootfs.tegraflash.tar.zst
```

Note: this hasn't been tested yet with a fresh checkout, not everything might be captured yet.

To flash, extract the image, then run `sudo ./initrd-flash` with the orin in bootloader mode, connected over USB.
