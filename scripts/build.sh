#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="${KERNEL_VERSION:-6.12.y}"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/unifreq/linux-6.12.y.git}"
ARCH=arm64
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"
LOCALVERSION="${KERNEL_LOCALVERSION:--pcp-n1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${ROOT_DIR}/.work"
SRC="${WORK}/linux"
PKG="${WORK}/package"
FRAGMENT="${ROOT_DIR}/config/n1-pcp.fragment"

rm -rf "${WORK}"
mkdir -p "${WORK}" "${PKG}"

echo "=========================================="
echo " S905 pCP Route B"
echo " Kernel : ${KERNEL_VERSION}"
echo " Source : ${KERNEL_REPO}"
echo "=========================================="

git clone --depth=1 --branch "${KERNEL_VERSION}" "${KERNEL_REPO}" "${SRC}"
cd "${SRC}"

echo "==> Kernel commit"
git rev-parse HEAD
git describe --always --tags || true

echo "==> Clean"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper

echo "==> Base config"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" defconfig

echo "==> Merge pCP/N1 fragment"
"${SRC}/scripts/kconfig/merge_config.sh" -m "${SRC}/.config" "${FRAGMENT}"

echo "==> Resolve Kconfig"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig

check_cfg() {
  local key="$1" allowed="$2" value
  value="$(grep -E "^${key}=" .config | head -n1 | cut -d= -f2- || true)"
  if [[ " ${allowed} " != *" ${value} "* ]]; then
    echo "ERROR: ${key}=${value:-UNSET}; expected: ${allowed}"
    exit 1
  fi
  echo "OK: ${key}=${value}"
}

echo "==> Verify critical config"
check_cfg CONFIG_ARM64 "y"
check_cfg CONFIG_ARCH_MESON "y"
check_cfg CONFIG_BLK_DEV_INITRD "y"
check_cfg CONFIG_DEVTMPFS "y"
check_cfg CONFIG_MMC_MESON_GX "y"
check_cfg CONFIG_EXT4_FS "y"
check_cfg CONFIG_SQUASHFS "y"
check_cfg CONFIG_USB "y"
check_cfg CONFIG_USB_STORAGE "y"
check_cfg CONFIG_USB_UAS "y m"
check_cfg CONFIG_STMMAC_ETH "y m"
check_cfg CONFIG_MESON_GXL_PHY "y m"
check_cfg CONFIG_SND "y"
check_cfg CONFIG_SND_USB_AUDIO "y m"
check_cfg CONFIG_MODULES "y"

DTS="${SRC}/arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dts"
DTB="${SRC}/arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dtb"

echo "==> Check N1 DTS"
test -f "${DTS}"
grep -q 'meson-gxl-s905d-phicomm-n1.dtb' "${SRC}/arch/arm64/boot/dts/amlogic/Makefile"
echo "OK: N1 DTS and DTB registration found"

echo "==> Build Image"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" LOCALVERSION="${LOCALVERSION}" -j"$(nproc)" Image

echo "==> Build DTBs via Kbuild"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" LOCALVERSION="${LOCALVERSION}" -j"$(nproc)" dtbs

if [[ ! -f "${DTB}" ]]; then
  echo "ERROR: N1 DTB was not generated"
  find "${SRC}/arch/arm64/boot/dts" -name 'meson-gxl-s905d-phicomm-n1.dtb' -print
  exit 1
fi

echo "==> Build modules"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" LOCALVERSION="${LOCALVERSION}" -j"$(nproc)" modules

echo "==> Install modules"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" LOCALVERSION="${LOCALVERSION}" INSTALL_MOD_PATH="${PKG}/rootfs" modules_install

echo "==> Package kernel"
mkdir -p "${PKG}/boot/dtb/amlogic"
cp arch/arm64/boot/Image "${PKG}/boot/Image"
cp "${DTB}" "${PKG}/boot/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb"
cp .config "${PKG}/kernel.config"
git rev-parse HEAD > "${PKG}/kernel.commit"

cat > "${PKG}/boot/uEnv.txt.example" <<'EOF'
LINUX=/Image
INITRD=/uInitrd
FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb
APPEND=root=/dev/mmcblk0p2 rootfstype=ext4 rw console=ttyAML0,115200n8 console=tty0
EOF

echo "==> Build completed"
find "${PKG}" -maxdepth 4 -type f -print
