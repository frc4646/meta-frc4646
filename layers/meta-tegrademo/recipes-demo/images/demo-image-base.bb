DESCRIPTION = "Tegra demo base image"

require demo-image-common.inc

IMAGE_FEATURES += " ssh-server-openssh"

ROOT_HOME="/root"
VOLATILE_LOG_DIR="no"
