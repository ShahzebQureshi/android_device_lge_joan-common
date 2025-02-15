#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
    vendor/lib/hw/audio.primary.msm8998.so)
        ${PATCHELF} --add-needed libprocessgroup.so "${2}"
        ;;
    vendor/lib64/hw/audio.primary.msm8998.so)
        ${PATCHELF} --add-needed libprocessgroup.so "${2}"
        ;;
    vendor/lib/hw/camera.msm8998.so)
        sed -i "s/libandroid\.so/libui_shim\.so/g" "${2}"
        ${PATCHELF} --remove-needed libsensor.so "${2}"
        ${PATCHELF} --remove-needed libgui.so "${2}"
        ${PATCHELF} --remove-needed libui.so "${2}"
        ;;
    vendor/lib/libmpbase.so)
        ${PATCHELF} --remove-needed libandroid.so "${2}"
        ;;
    vendor/lib/libarcsoft_beauty_picselfie.so)
        ${PATCHELF} --remove-needed libandroid.so "${2}"
        ${PATCHELF} --remove-needed libjnigraphics.so "${2}"
        ;;
    vendor/lib/libfilm_emulation.so)
        ${PATCHELF} --remove-needed libjnigraphics.so "${2}"
        ;;
    vendor/lib/libmmcamera_bokeh.so)
        ${PATCHELF} --replace-needed libui.so libui_shim.so "${2}"
        ;;
    esac
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON:-$VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

    # Reinitialize the helper for Q910 blobs
    echo "Gathering Q910 blobs"
    echo "Please provide the path to Q910 blobs"
    echo -n "Path:"
    read SRC2

    if [ -z "${SRC2}" ]; then
        SRC2="adb"
    fi

    # Initialize the helper
    # Don't clean vendor blobs in common when extracting from Q910
    setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON:-$VENDOR}" "${ANDROID_ROOT}" true false

    extract "${MY_DIR}/proprietary-files_Q910.txt" "${SRC2}" ${KANG} --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../../${VENDOR}/${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../../${VENDOR}/${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
