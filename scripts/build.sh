#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="${KERNEL_VERSION:-6.12.67}"
KERNEL_TAG="v${KERNEL_VERSION}"
KERNEL_LOCALVERSION="${KERNEL_LOCALVERSION:--pcp-s905}"
ARCH=arm64
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${ROOT_DIR}/.work"
SRC="${WORK}/linux"
PKG="${WORK}/package/kernel"
FRAGMENT="${ROOT_DIR}/config/n1.fragment"

rm -rf "${WORK}"
mkdir -p "${WORK}" "${PKG}"

echo "==> Kernel: ${KERNEL_TAG}"
echo "==> Target: Phicomm N1 / S905D"
echo "==> ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}"

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
  echo "ERROR: missing cross compiler: ${CROSS_COMPILE}gcc" >&2
  exit 1
fi

echo "==> Cloning Linux stable ${KERNEL_TAG}"
git clone --depth=1 --branch "${KERNEL_TAG}" \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git "${SRC}"

cd "${SRC}"

HEAD_COMMIT="$(git rev-parse HEAD)"
echo "==> Kernel commit: ${HEAD_COMMIT}"
echo "==> Kernel describe: $(git describe --tags --always --dirty 2>/dev/null || true)"

git cat-file -e "HEAD^{commit}"

echo "==> Clean source tree"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" mrproper

echo "==> Base config (in-tree)"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" defconfig

echo "==> Merge N1 fragment"
"${SRC}/scripts/kconfig/merge_config.sh" \
  -m \
  "${SRC}/.config" \
  "${FRAGMENT}"

echo "==> Resolve Kconfig dependencies"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" olddefconfig

state() {
  local sym="$1"
  sed -n "s/^${sym}=//p" .config | head -n1
}

expect_y_or_m() {
  local sym="$1"
  local v
  v="$(state "${sym}")"
  if [[ "${v}" != "y" && "${v}" != "m" ]]; then
    echo "ERROR: ${sym}=${v:-n}, expected y or m" >&2
    return 1
  fi
  echo "OK: ${sym}=${v}"
}

expect_y() {
  local sym="$1"
  local v
  v="$(state "${sym}")"
  if [[ "${v}" != "y" ]]; then
    echo "ERROR: ${sym}=${v:-n}, expected y" >&2
    return 1
  fi
  echo "OK: ${sym}=y"
}

echo "==> Final kernel identity"
grep -E '^(CONFIG_LOCALVERSION=|CONFIG_LOCALVERSION_AUTO=)' .config || true

echo "==> Key final config"
for s in \
  CONFIG_ARM64 CONFIG_OF CONFIG_BLK_DEV_INITRD \
  CONFIG_MMC_MESON_GX CONFIG_EXT4_FS CONFIG_SQUASHFS \
  CONFIG_USB CONFIG_USB_XHCI_HCD CONFIG_USB_DWC3 \
  CONFIG_USB_STORAGE CONFIG_USB_UAS CONFIG_SCSI \
  CONFIG_STMMAC_ETH CONFIG_STMMAC_PLATFORM CONFIG_DWMAC_MESON \
  CONFIG_MESON_GXL_PHY CONFIG_SERIAL_MESON \
  CONFIG_SOUND CONFIG_SND CONFIG_SND_PCM CONFIG_SND_USB \
  CONFIG_SND_USB_AUDIO CONFIG_SND_SOC \
  CONFIG_SND_MESON_AIU CONFIG_SND_MESON_GX_SOUND_CARD \
  CONFIG_MODULES; do
  printf '%-42s %s\n' "${s}" "$(state "${s}")"
done

echo "==> Verify boot-critical options"
for s in \
  CONFIG_ARM64 CONFIG_OF CONFIG_BLK_DEV_INITRD \
  CONFIG_DEVTMPFS CONFIG_DEVTMPFS_MOUNT \
  CONFIG_MMC CONFIG_MMC_BLOCK CONFIG_MMC_MESON_GX \
  CONFIG_EXT4_FS CONFIG_SQUASHFS CONFIG_BLK_DEV_LOOP \
  CONFIG_USB CONFIG_USB_XHCI_HCD CONFIG_USB_DWC3 \
  CONFIG_USB_STORAGE CONFIG_SCSI CONFIG_BLK_DEV_SD \
  CONFIG_NET CONFIG_NETDEVICES CONFIG_ETHERNET CONFIG_PHYLIB \
  CONFIG_TTY CONFIG_SERIAL_MESON CONFIG_SERIAL_MESON_CONSOLE \
  CONFIG_SOUND CONFIG_SND CONFIG_SND_PCM CONFIG_SND_USB \
  CONFIG_SND_SOC CONFIG_MODULES; do
  expect_y "${s}"
done

echo "==> Verify driver options (y or m)"
for s in \
  CONFIG_USB_UAS \
  CONFIG_STMMAC_ETH CONFIG_STMMAC_PLATFORM CONFIG_DWMAC_GENERIC \
  CONFIG_DWMAC_MESON CONFIG_MESON_GXL_PHY \
  CONFIG_SND_USB_AUDIO CONFIG_SND_MESON_AIU \
  CONFIG_SND_MESON_CARD_UTILS CONFIG_SND_MESON_CODEC_GLUE \
  CONFIG_SND_MESON_GX_SOUND_CARD; do
  expect_y_or_m "${s}"
done

echo "==> Build kernel Image"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
  LOCALVERSION="${KERNEL_LOCALVERSION}" -j"$(nproc)" Image

echo "==> Build N1 DTB"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
  LOCALVERSION="${KERNEL_LOCALVERSION}" \
  meson-gxl-s905d-phicomm-n1.dtb

echo "==> Build modules"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
  LOCALVERSION="${KERNEL_LOCALVERSION}" -j"$(nproc)" modules

echo "==> Install modules into package"
make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
  LOCALVERSION="${KERNEL_LOCALVERSION}" \
  INSTALL_MOD_PATH="${PKG}/rootfs" modules_install

mkdir -p "${PKG}/boot" "${PKG}/config"
cp "arch/arm64/boot/Image" \
  "${PKG}/boot/Image-${KERNEL_VERSION}-pcp-s905"
cp "arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dtb" \
  "${PKG}/boot/meson-gxl-s905d-phicomm-n1.dtb"
cp ".config" "${PKG}/config/kernel.config"
cp "${FRAGMENT}" "${PKG}/config/n1.fragment"
printf '%s\n' "${HEAD_COMMIT}" > "${PKG}/config/kernel.commit"
printf '%s\n' "${KERNEL_VERSION}" > "${PKG}/config/kernel.version"

echo "==> Package contents"
find "${PKG}" -type f -printf '%P\n' | sort

echo "==> Kernel build complete"
