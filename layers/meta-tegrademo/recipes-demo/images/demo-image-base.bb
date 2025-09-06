DESCRIPTION = "Tegra demo base image"

require demo-image-common.inc

IMAGE_FEATURES += " ssh-server-openssh"

ROOT_HOME="/root"
FILESYSTEM_PERMS_TABLES="files/fs-perms.txt"
