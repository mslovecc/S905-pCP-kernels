#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="${KERNEL_VERSION:-6.12.67}"
KERNEL_TAG="v${KERNEL_VERSION}"
FRAGMENT="${GITHUB_WORKSPACE}/config/n1.fragment"

WORK="${GITHUB_WORKSPACE}/.work"
SRC="${WORK}/linux"
OUT="${WORK}/out"
PKG="${WORK}/package"

rm -rf "${WORK}"
mkdir -p "${WORK}" "${PKG}"

echo "== piCorePlayer N1 kernel =="
echo "Kernel: ${KERNEL_TAG}"
echo "Board : Phicomm N1 / S905D / Meson GXL"

echo
echo "== Kernel source =="

git clone --depth 1 --branch "${KERNEL_TAG}" \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
  "${SRC}"

echo
echo "== Kernel commit =="
git -C "${SRC}" rev-parse HEAD

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export KBUILD_OUTPUT="${OUT}"

echo
echo "== Configure =="

make -C "${SRC}" O="${OUT}" defconfig

"${SRC}/scripts/kconfig/merge_config.sh" \
  -m \
  "${OUT}/.config" \
  "${FRAGMENT}"

make -C "${SRC}" O="${OUT}" olddefconfig

echo
echo "== Selected configuration after olddefconfig =="

CONFIG_KEYS=(
  CONFIG_ARM64
  CONFIG_OF
  CONFIG_BLK_DEV_INITRD
  CONFIG_DEVTMPFS
  CONFIG_DEVTMPFS_MOUNT
  CONFIG_MMC
  CONFIG_MMC_BLOCK
  CONFIG_MMC_MESON_GX
  CONFIG_EXT4_FS
  CONFIG_SQUASHFS
  CONFIG_BLK_DEV_LOOP
  CONFIG_FAT_FS
  CONFIG_VFAT_FS
  CONFIG_USB
  CONFIG_USB_XHCI_HCD
  CONFIG_USB_DWC3
  CONFIG_USB_STORAGE
  CONFIG_USB_UAS
  CONFIG_SCSI
  CONFIG_BLK_DEV_SD
  CONFIG_NET
  CONFIG_NETDEVICES
  CONFIG_ETHERNET
  CONFIG_PHYLIB
  CONFIG_STMMAC_ETH
  CONFIG_STMMAC_PLATFORM
  CONFIG_DWMAC_GENERIC
  CONFIG_DWMAC_MESON
  CONFIG_MESON_GXL_PHY
  CONFIG_TTY
  CONFIG_SERIAL_MESON
  CONFIG_SOUND
  CONFIG_SND
  CONFIG_SND_PCM
  CONFIG_SND_USB_AUDIO
  CONFIG_SND_SOC
  CONFIG_SND_MESON_AIU
  CONFIG_SND_MESON_CARD_UTILS
  CONFIG_SND_MESON_CODEC_GLUE
  CONFIG_SND_MESON_GX_SOUND_CARD
  CONFIG_MODULES
)

get_config() {
  local key="$1"
  local value
  value="$(grep -E "^${key}=" "${OUT}/.config" | head -n1 | cut -d= -f2- || true)"
  if [[ -n "${value}" ]]; then
    printf '%s' "${value}"
  elif grep -q "^# ${key} is not set" "${OUT}/.config"; then
    printf 'n'
  else
    printf '<unset>'
  fi
}

for key in "${CONFIG_KEYS[@]}"; do
  printf '%-38s %s\n' "${key}" "$(get_config "${key}")"
done

echo
echo "== Verify boot-critical configuration =="

REQUIRED_Y=(
  CONFIG_ARM64
  CONFIG_OF
  CONFIG_BLK_DEV_INITRD
  CONFIG_DEVTMPFS
  CONFIG_DEVTMPFS_MOUNT
  CONFIG_MMC
  CONFIG_MMC_BLOCK
  CONFIG_MMC_MESON_GX
  CONFIG_EXT4_FS
  CONFIG_SQUASHFS
  CONFIG_BLK_DEV_LOOP
  CONFIG_FAT_FS
  CONFIG_VFAT_FS
  CONFIG_USB
  CONFIG_SCSI
  CONFIG_BLK_DEV_SD
  CONFIG_NET
  CONFIG_NETDEVICES
  CONFIG_ETHERNET
  CONFIG_TTY
  CONFIG_SERIAL_MESON
  CONFIG_MODULES
)

FAILED=0

for key in "${REQUIRED_Y[@]}"; do
  value="$(get_config "${key}")"
  if [[ "${value}" == "y" ]]; then
    echo "OK: ${key}=y"
  else
    echo "ERROR: ${key}: expected y, got ${value}"
    FAILED=1
  fi
done

echo
echo "== Verify pCP audio/network drivers =="

ALLOWED_TRISTATE=(
  CONFIG_USB_STORAGE
  CONFIG_USB_UAS
  CONFIG_STMMAC_ETH
  CONFIG_STMMAC_PLATFORM
  CONFIG_DWMAC_GENERIC
  CONFIG_DWMAC_MESON
  CONFIG_MESON_GXL_PHY
  CONFIG_SND
  CONFIG_SND_PCM
  CONFIG_SND_USB_AUDIO
  CONFIG_SND_SOC
  CONFIG_SND_MESON_AIU
  CONFIG_SND_MESON_CARD_UTILS
  CONFIG_SND_MESON_CODEC_GLUE
  CONFIG_SND_MESON_GX_SOUND_CARD
)

for key in "${ALLOWED_TRISTATE[@]}"; do
  value="$(get_config "${key}")"
  if [[ "${value}" == "y" || "${value}" == "m" ]]; then
    echo "OK: ${key}=${value}"
  else
    echo "ERROR: ${key}: audio/network driver is disabled (${value})"
    FAILED=1
  fi
done

if [[ "${FAILED}" -ne 0 ]]; then
  echo
  echo "Kernel configuration verification FAILED"
  exit 1
fi

echo
echo "Kernel configuration verification PASSED"

echo
echo "== Build Image, DTBs and modules =="

make -C "${SRC}" O="${OUT}" -j"$(nproc)" \
  Image dtbs modules

echo
echo "== Install modules =="

rm -rf "${PKG}/modules"

make -C "${SRC}" O="${OUT}" \
  INSTALL_MOD_PATH="${PKG}/modules" \
  modules_install

echo
echo "== Package kernel =="

mkdir -p "${PKG}/kernel/dtb/amlogic"

cp "${OUT}/arch/arm64/boot/Image" \
  "${PKG}/kernel/Image"

cp "${OUT}/arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dtb" \
  "${PKG}/kernel/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb"

cp "${OUT}/.config" \
  "${PKG}/kernel/config-6.12.67-pcp-s905"

cat > "${PKG}/kernel/build-info.txt" <<EOF
project=tinycore-s905-kernel
profile=picoreplayer-n1
version=v0.2.0
kernel_version=${KERNEL_VERSION}
kernel_tag=${KERNEL_TAG}
kernel_commit=$(git -C "${SRC}" rev-parse HEAD)
board=phicomm-n1
soc=amlogic-s905d
family=meson-gxl
arch=arm64
purpose=piCorePlayer
EOF

tar -C "${PKG}/modules" \
  -cJf "${PKG}/kernel/modules-6.12.67-pcp-s905.tar.xz" \
  lib/modules

rm -rf "${PKG}/modules"

(
  cd "${PKG}/kernel"
  sha256sum \
    Image \
    dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb \
    config-6.12.67-pcp-s905 \
    modules-6.12.67-pcp-s905.tar.xz \
    > SHA256SUMS
)

echo
echo "== Artifacts =="

find "${PKG}/kernel" -type f -maxdepth 4 -printf '%P\n' | sort

echo
echo "== SHA256SUMS =="
cat "${PKG}/kernel/SHA256SUMS"

echo
echo "piCorePlayer N1 kernel build completed successfully."
