#!/usr/bin/env bash
set -eu

umask 022

# Define
ROOT="${PWD}"

ANDROID_VERSION="9.0-r2"

CHROMEOS_VERSION="13816.64.0_drallion"
CHROMEOS_RECOVERY="chromeos_${CHROMEOS_VERSION}_recovery_stable-channel_mp-v2"

# Root Check
if [[ "${UID}" != 0 ]]; then
    echo "Pleas run as sudo"
    exit 1
fi

# Clean
rm -rf "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}"

# Create Directory
mkdir -pv "${ROOT}"/mnt/{chromeos,system,ramdisk,vendor}
mkdir -p "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}"

# Mount
loop_device="$(losetup -r -f --show --partscan ${ROOT}/source/${CHROMEOS_RECOVERY}.bin)"

function cleaning() {
    set +e
    mountpoint -q "${ROOT}/mnt/vendor" && umount "${ROOT}/mnt/vendor"
	mountpoint -q "${ROOT}/mnt/chromeos" && umount "${ROOT}/mnt/chromeos"
    mountpoint -q "${ROOT}/mnt/system" && umount "${ROOT}/mnt/system"
    losetup -d "${loop_device}"
    rm -rf "${ROOT}/mnt"
    rm -r "${ROOT}/squashfs-root"
}

trap cleaning EXIT

## Chrome OS
mount -r "${loop_device}p3" "${ROOT}/mnt/chromeos"

## Vendor
mount -r -t squashfs "${ROOT}/mnt/chromeos/opt/google/containers/android/vendor.raw.img" "${ROOT}/mnt/vendor"

## System 
unsquashfs "${ROOT}/source/android-${ANDROID_VERSION}/system.sfs"
e2fsck -f "${ROOT}/squashfs-root/system.img"
resize2fs "${ROOT}/squashfs-root/system.img" 3G
mount "${ROOT}/squashfs-root/system.img" "${ROOT}/mnt/system"

## Ramdisk
(
    cd "${ROOT}/mnt/ramdisk"
    zcat "${ROOT}/source/android-${ANDROID_VERSION}/ramdisk.img" | cpio -idm > /dev/null
)

# Install
## Houdini
rsync -rtv "${ROOT}/mnt/vendor/bin/houdini" "${ROOT}/mnt/system/bin/"
rsync -rtv "${ROOT}/mnt/vendor/bin/houdini64" "${ROOT}/mnt/system/bin/"
rsync -rtv "${ROOT}/mnt/vendor/lib/arm" "${ROOT}/mnt/system/lib"
rsync -rtv "${ROOT}/mnt/vendor/lib/libhoudini.so" "${ROOT}/mnt/system/lib/"
rsync -rtv "${ROOT}/mnt/vendor/lib64/arm64" "${ROOT}/mnt/system/lib64"
rsync -rtv "${ROOT}/mnt/vendor/lib64/libhoudini.so" "${ROOT}/mnt/system/lib64/"

mv -v "${ROOT}/mnt/system/lib/arm/cpuinfo.pure32" "${ROOT}/mnt/system/lib/arm/cpuinfo"

sed -i -r \
    '$ i [ "$(getprop ro.zygote)" = "zygote64_32" -a -z "$1" ] && exec $0 64\n' \
    "${ROOT}/mnt/system/bin/enable_nativebridge"

echo "ro.zygote=zygote64_32" >> "${ROOT}/mnt/system/build.prop"

sed -i -r \
    's/^(ro\.product\.cpu\.abilist)=.*$/\1=x86_64,x86,arm64-v8a,armeabi-v7a,armeabi/' \
    "${ROOT}/mnt/system/build.prop"

sed -i -r \
    's/^(ro\.product\.cpu\.abilist64)=.*$/\1=x86_64,arm64-v8a/' \
    "${ROOT}/mnt/system/build.prop"

sed -i -r \
    's/^(ro\.dalvik\.vm\.native\.bridge)=.*$/\1=libhoudini.so/' \
    "${ROOT}/mnt/system/build.prop"

## Widevine
rsync -rtv "${ROOT}/mnt/vendor/bin/hw/android.hardware.drm@1.1-service.widevine" "${ROOT}/mnt/system/vendor/bin/hw/"
rsync -rtv "${ROOT}/mnt/vendor/etc/init/android.hardware.drm@1.1-service.widevine.rc" "${ROOT}/mnt/system/vendor/etc/init/"
rsync -rtv "${ROOT}/mnt/vendor/lib/libwvhidl.so" "${ROOT}/mnt/system/lib/"

## Unroot
rm -fv "${ROOT}/mnt/system/bin/su"
rm -fv "${ROOT}/mnt/system/xbin/su"

sed -i -r \
    '/^ro\.adb\.secure=.*$/d' \
    "${ROOT}/mnt/ramdisk/default.prop"

sed -i -r \
    's/^(ro\.secure)=.*$/ro.adb.secure=1\nro.secure=1/' \
    "${ROOT}/mnt/ramdisk/default.prop"

sed -i -r \
    's/^(ro\.debuggable)=.*$/\1=0/' \
    "${ROOT}/mnt/ramdisk/default.prop"

sed -i -r \
    's/^(persist\.sys\.usb\.config)=.*$/\1=mtp/' \
    "${ROOT}/mnt/ramdisk/default.prop"

## Fix init.sh
sed -i -r \
    's/^(governor)=.*$/\1="performance"/' \
    "${ROOT}/mnt/system/etc/init.sh"

## Fix idc
cat <<EOF > "${ROOT}/mnt/system/usr/idc/QEMU_Virtio_Tablet.idc"
touch.deviceType = touchScreen
touch.gestureMode = spots
touch.orientationAware = 1
touch.toolSize.calibration = default
touch.pressure.calibration = default
touch.size.calibration = default
touch.orientation.calibration = none
device.internal = 1
EOF

# qemu-umamusume
## Copy initrd.img
rsync -rtv "${ROOT}/source/android-${ANDROID_VERSION}/initrd.img" "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}"

## Copy kernel
rsync -rtv "${ROOT}/source/android-${ANDROID_VERSION}/kernel" "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}"

## System
umount "${ROOT}/mnt/system"
mksquashfs "${ROOT}/squashfs-root" "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}/system.sfs"

## Ramdisk
(
    cd "${ROOT}/mnt/ramdisk"
    find . | cpio -o -H newc | gzip > "${ROOT}/qemu-umamusume/android-${ANDROID_VERSION}/ramdisk.img"
)
