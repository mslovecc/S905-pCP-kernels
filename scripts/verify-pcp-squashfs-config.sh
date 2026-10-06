#!/usr/bin/env bash
set -euo pipefail

cfg="${1:?config path required}"

get_cfg() {
    local sym="$1"
    awk -v s="$sym" '
        $0 == s "=y" { print "y"; found=1; exit }
        $0 == s "=m" { print "m"; found=1; exit }
        $0 == "# " s " is not set" { print "n"; found=1; exit }
        END { if (!found) print "missing" }
    ' "$cfg"
}

required=(
  CONFIG_ARM64
  CONFIG_ARCH_MESON

  CONFIG_BLK_DEV_INITRD
  CONFIG_DEVTMPFS
  CONFIG_DEVTMPFS_MOUNT
  CONFIG_BLOCK
  CONFIG_BLK_DEV_LOOP

  CONFIG_SQUASHFS
  CONFIG_SQUASHFS_XZ
  CONFIG_SQUASHFS_ZSTD
  CONFIG_SQUASHFS_LZ4
  CONFIG_SQUASHFS_LZO
  CONFIG_SQUASHFS_ZLIB

  CONFIG_EXT4_FS
  CONFIG_FAT_FS
  CONFIG_MSDOS_FS
  CONFIG_VFAT_FS

  CONFIG_MMC
  CONFIG_MMC_BLOCK
  CONFIG_MMC_MESON_GX
  CONFIG_MMC_MESON_MX_SDIO

  CONFIG_SCSI_MOD
  CONFIG_SCSI_COMMON
  CONFIG_SCSI
  CONFIG_BLK_DEV_SD

  CONFIG_USB
  CONFIG_USB_XHCI_HCD
  CONFIG_USB_XHCI_PLATFORM
  CONFIG_USB_EHCI_HCD
  CONFIG_USB_EHCI_HCD_PLATFORM
  CONFIG_USB_STORAGE
  CONFIG_USB_UAS
  CONFIG_USB_DWC3
  CONFIG_USB_DWC3_MESON_G12A
  CONFIG_PHY_MESON_GXL_USB2

  CONFIG_PROC_FS
  CONFIG_SYSFS
  CONFIG_TMPFS
  CONFIG_BINFMT_ELF

  CONFIG_RD_GZIP
  CONFIG_RD_XZ
  CONFIG_RD_ZSTD
  CONFIG_RD_LZ4
  CONFIG_RD_LZO
)

bad=0

for sym in "${required[@]}"; do
    value="$(get_cfg "$sym")"
    printf '%-40s %s\n' "$sym" "$value"
    if [ "$value" != "y" ]; then
        bad=1
    fi
done

if [ "$bad" -ne 0 ]; then
    echo
    echo "ERROR: pCP SquashFS early-boot contract is not satisfied."
    exit 1
fi

echo
echo "PASS: all declared pCP-N1 SquashFS early-boot requirements are =y."
