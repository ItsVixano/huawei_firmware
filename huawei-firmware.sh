#!/bin/bash
# Copyright (C) 2024 Giovanni Ricca
# SPDX-License-Identifier: GPL-3.0-or-later

# Logging defs
LOGI() {
    echo -e "\n\033[32m[INFO] huawei-firmware: $1\033[0m"
}

LOGW() {
    echo -e "\n\033[33m[WARNING] huawei-firmware: $1\033[0m"
}

LOGE() {
    echo -e "\n\033[31m[ERROR] huawei-firmware: $1\033[0m"
}

MY_DIR="${PWD}"
MY_BINS="${MY_DIR}/bin"

image_blocklist=(
    "BASE_VER"
    "BASE_VERLIST"
    "CACHE"
    "CRC"
    "CURVER"
    "CUST"
    "ENG_SYSTEM"
    "ENG_VENDOR"
    "ERECOVERY_KERNEL"
    "ERECOVERY_RAMDIS"
    "ERECOVERY_VBMETA"
    "ERECOVERY_VENDOR"
    "KERNEL"
    "KPATCH"
    "ODM"
    "PACKAGE_TYPE"
    "PATCH"
    "PREAS"
    "PREAVS"
    "PRETS"
    "PRETVS"
    "PRODUCT"
    "RAMDISK"
    "RECOVERY_RAMDISK"
    "RECOVERY_VBMETA"
    "RECOVERY_VENDOR"
    "SHA256RSA"
    "SUPER"
    "SYSTEM"
    "USERDATA"
    "VENDOR"
    "VERLIST"
)

fastboot_first_stage=(
    # NOTE: They *MUST* be flashed in a specific order!
    "HISIUFS_GPT"
    "EFI"
    "XLOADER"
    "DTS"
    "DTO"
    "FASTBOOT"
)

while [ "$#" -gt 0 ]; do
    case "${1}" in
        -d | --device)
            DEVICE=${2}
            ;;
        -f | --fw-base)
            FW_BASE=${2}
            ;;
        -z | --zip)
            UPDATE_PACKAGE_ZIP=${2}
            ;;
        -u | --update-app)
            UPDATE_PACKAGE_APP=${2}
            ;;
    esac
    shift
done

if [[ -z ${DEVICE} || -z ${FW_BASE} || (-z ${UPDATE_PACKAGE_ZIP} && -z ${UPDATE_PACKAGE_APP}) ]]; then
    LOGE "Please define the required values \`-d|--device\`, \`-f|--fw-base\` and either \`-z|--zip\` or \`-u|--update-app\`"
    exit 0
fi

if [[ -n ${UPDATE_PACKAGE_ZIP} && -n ${UPDATE_PACKAGE_APP} ]]; then
    LOGE "Please define either \`-z|--zip\` or \`-u|--update-app\`, not both."
    exit 1
fi

# Cleanup dir
rm -rf ${MY_DIR}/output ${MY_DIR}/working
mkdir ${MY_DIR}/working ${MY_DIR}/output

# Extract UPDATE.app
if [ -f "${UPDATE_PACKAGE_ZIP}" ]; then
    if ! unzip -l "${UPDATE_PACKAGE_ZIP}" 2>/dev/null | grep -q "UPDATE.APP"; then
        LOGE "\`UPDATE.APP\` file does not exist in the zip package."
        exit 1
    fi

    LOGI "Extracting \`UPDATE.APP\` from \`${UPDATE_PACKAGE_ZIP}\`..."
    if ! unzip -j ${UPDATE_PACKAGE_ZIP} UPDATE.APP -d ${MY_DIR}/working &>/dev/null; then
        LOGE "Failed to unzip \`${UPDATE_PACKAGE_ZIP}\`. It may not be a valid zip file."
        exit 1
    fi
elif [ -f "${UPDATE_PACKAGE_APP}" ]; then
    # Directly copy the UPDATE.APP file on working/
    cp ${UPDATE_PACKAGE_APP} ${MY_DIR}/working
else
    LOGE "Neither zip file \`${UPDATE_PACKAGE_ZIP}\` nor app file \`${UPDATE_PACKAGE_APP}\` exists."
    exit 1
fi

LOGI "Extracting \`UPDATE.APP\` using \`update-extractor.py\`..."
if ! ${MY_BINS}/update-extractor.py ${MY_DIR}/working/UPDATE.APP -e -o ${MY_DIR}/output/images &>/dev/null; then
    LOGE "Failed to extract \`UPDATE.APP\` using \`update-extractor.py\`."
    exit 1
fi
for image in ${image_blocklist[@]}; do
    rm -rf ${MY_DIR}/output/images/${image}.img
done

# Generate fastboot script (Linux)
LOGI "Generating \`${MY_DIR}/output/flash_fw.sh\` ..."
echo -e "#!/bin/bash\n# Generated with \`huawei-firmware.sh\` script\n\nfastboot erase misc\n" >${MY_DIR}/output/flash_fw.sh
for image in "${fastboot_first_stage[@]}"; do
    # EMUI 9>
    if [ "$image" == "HISIUFS_GPT" ] && [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ptable images/HISIUFS_GPT.img" >>${MY_DIR}/output/flash_fw.sh
        continue
    # EMUI 8<
    elif [ "$image" == "EFI" ] && [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ptable images/EFI.img" >>${MY_DIR}/output/flash_fw.sh
        continue
    fi

    if [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ${image,,} images/${image}.img" >>${MY_DIR}/output/flash_fw.sh
    fi
done
echo -e "\nsleep 1\n\nfastboot reboot bootloader\n\nsleep 1\n" >>${MY_DIR}/output/flash_fw.sh
for image in ${MY_DIR}/output/images/*.img; do
    image_name=$(basename ${image} .img)
    if [[ ! "${fastboot_first_stage[@]}" =~ "${image_name}" ]]; then
        echo -e "fastboot flash ${image_name,,} images/${image_name}.img" >>${MY_DIR}/output/flash_fw.sh
    fi
done
chmod +x ${MY_DIR}/output/flash_fw.sh

# Generate fastboot script (Windows)
LOGI "Generating \`${MY_DIR}/output/flash_fw.bat\` ..."
echo -e "@echo off\nREM Generated with \`huawei-firmware.sh\` script\n\nfastboot erase misc\n" >${MY_DIR}/output/flash_fw.bat
for image in "${fastboot_first_stage[@]}"; do
    # EMUI 9>
    if [ "$image" == "HISIUFS_GPT" ] && [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ptable images\HISIUFS_GPT.img" >>${MY_DIR}/output/flash_fw.bat
        continue
    # EMUI 8<
    elif [ "$image" == "EFI" ] && [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ptable images\\\EFI.img" >>${MY_DIR}/output/flash_fw.bat
        continue
    fi

    if [ -f "${MY_DIR}/output/images/${image}.img" ]; then
        echo -e "fastboot flash ${image,,} images\\${image}.img" >>${MY_DIR}/output/flash_fw.bat
    fi
done
echo -e "\ntimeout /T 1 /nobreak\n\nfastboot reboot bootloader\n\ntimeout /T 1 /nobreak\n" >>${MY_DIR}/output/flash_fw.bat
for image in ${MY_DIR}/output/images/*.img; do
    image_name=$(basename ${image} .img)
    if [[ ! "${fastboot_first_stage[@]}" =~ "${image_name}" ]]; then
        echo -e "fastboot flash ${image_name,,} images\\${image_name}.img" >>${MY_DIR}/output/flash_fw.bat
    fi
done

# Zip everything
LOGI "Creating fastboot zip package \`${MY_DIR}/output/${DEVICE}-${FW_BASE}_update_fw_base.zip\` ..."
cd ${MY_DIR}/output
zip -r ${DEVICE}-${FW_BASE}_update_fw_base.zip ./* &>/dev/zero
cd ${MY_DIR}

LOGI "Done!"
