#!/usr/bin/env bash
set -eu

umask 022

# Define
ROOT="${PWD}"

ANDROID_VERSION="9.0-r2"
ANDROID_RPM="android-x86-${ANDROID_VERSION}.x86_64.rpm"

CHROMEOS_VERSION="13816.64.0_drallion"
CHROMEOS_RECOVERY="chromeos_${CHROMEOS_VERSION}_recovery_stable-channel_mp-v2"

# Root Check
if [[ "${UID}" == 0 ]]; then
    echo "Pleas run as user"
    exit 1
fi

# Create Directory
mkdir -pv "${ROOT}/source"

# Download
## Chrome OS Recovery
if [[ ! -f "${ROOT}/source/${CHROMEOS_RECOVERY}.bin.zip" ]]; then
    wget -O \
        "${ROOT}/source/${CHROMEOS_RECOVERY}.bin.zip" \
        "https://dl.google.com/dl/edgedl/chromeos/recovery/${CHROMEOS_RECOVERY}.bin.zip"
fi

## Android x86 RPM
if [[ ! -f "${ROOT}/source/${ANDROID_RPM}" ]]; then
    wget -O \
        "${ROOT}/source/${ANDROID_RPM}" \
        "https://osdn.net/frs/redir.php?m=constant&f=android-x86%2F71931%2F${ANDROID_RPM}"
fi

# Extract
## Chrome OS Recovery
if [[ ! -f "${ROOT}/source/${CHROMEOS_RECOVERY}.bin" ]]; then
    bsdtar xfv "${ROOT}/source/${CHROMEOS_RECOVERY}.bin.zip" -C "${ROOT}/source"
fi

## Android x86 RPM
if [[ ! -d "${ROOT}/source/android-${ANDROID_VERSION}" ]]; then
    bsdtar xfv "${ROOT}/source/${ANDROID_RPM}" -C "${ROOT}/source"
fi

# Create Patched Image
sudo "${ROOT}/install.sh"

# Build Package
## qemu-virtio-tablet-patched
(
    cd "${ROOT}/qemu-virtio-tablet-patched"
    makepkg -si
)

## qemu-umamusume
(
    cd "${ROOT}/qemu-umamusume"
    makepkg -si
)
