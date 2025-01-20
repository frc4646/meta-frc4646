#!/usr/bin/env python3

import sys
import contextlib
import tempfile
import os
import subprocess

@contextlib.contextmanager
def scoped_loopback(image):
    """Mounts an image as a loop back device."""
    result = subprocess.run(["sudo", "losetup", "--show", "-f", image],
                            check=True,
                            stdout=subprocess.PIPE)
    device = result.stdout.decode('utf-8').strip()
    print("Mounted", image, "to", repr(device), file=sys.stderr)
    try:
        yield device
    finally:
        subprocess.run(["sudo", "losetup", "-d", device], check=True)


@contextlib.contextmanager
def scoped_mount(image):
    """Mounts an image as a partition."""
    partition = f"{image}.partition"
    try:
        os.mkdir(partition)
    except FileExistsError:
        pass

    result = subprocess.run(["sudo", "mount", "-o", "loop", image, partition],
                            check=True)

    try:
        yield partition
    finally:
        subprocess.run(["sudo", "umount", partition], check=True)

def make_image(image):
    """Makes an image and creates an xfs filesystem on it."""
    print("--> Creating NEW image ", f"{image}", file=sys.stderr)
    result = subprocess.run([
        "dd", "if=/dev/zero", f"of={image}", "bs=1", "count=0",
        "seek=8589934592"
    ],
                            check=True)

    with scoped_loopback(image) as loopback:
        subprocess.run([
            "sudo", "mkfs.xfs", "-d", "su=128k", "-d", "sw=1", "-L", "rootfs",
            loopback
        ],
                       check=True)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage:", file=sys.stderr)
        print("  to_xfs ext3.rootfs.tegraflash.tar.gz xfs.rootfs.tegraflash.tar.zstd", file=sys.stderr)
        sys.exit(1)

    EXT3 = sys.argv[1]
    XFS = sys.argv[2]

    print(f'Converting {EXT3}(ext3) to {XFS}(xfs)')

    with tempfile.TemporaryDirectory() as tempdir:
        extracted_tegraflash = os.path.join(tempdir, 'tegraflash')
        os.mkdir(extracted_tegraflash)

        print(f'Extracting original image to {extracted_tegraflash}')
        subprocess.run([
            "tar",
            "xf",
            EXT3,
            "-C",
            extracted_tegraflash,
        ],
                       check=True)

        ext4 = os.path.join(extracted_tegraflash, 'demo-image-base.ext4')
        orig_ext4 = os.path.join(tempdir, 'demo-image-base.ext4.orig')

        os.rename(ext4, orig_ext4)

        make_image(ext4)

        print(f'Creating empty XFS image')
        with scoped_mount(orig_ext4) as ext4_partition:
            with scoped_mount(ext4) as xfs_partition:
                print(f'Copying contents into image')
                subprocess.run([
                    "sudo",
                    "rsync",
                    "-avxtX",
                    "--delete-before",
                    ext4_partition + '/',
                    xfs_partition,
                ],
                               check=True)

                subprocess.run([
                    "sudo",
                    "rmdir",
                    xfs_partition + '/lost+found',
                ],
                               check=True)

        # Make sure the image is flushed to disk so it doesn't change while tar
        # is reading it.
        subprocess.run(['sync'])

        print(f'Compressing results')
        subprocess.run([
            "tar",
            "-C",
            extracted_tegraflash,
            "-I",
            "zstd --ultra -6 -T0",
            "-cvf",
            XFS,
            '.',
        ],
                       check=True)

    sys.exit(0)
