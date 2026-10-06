# S905-pCP-kernels v0.4.1

## Goal

This version is specifically a **pCP SquashFS boot kernel**, not merely
another N1-capable ophub kernel.

It keeps ophub/unifreq as the hardware/kernel generation mechanism, but
replaces the previous "stable config only" approach with an explicit,
auditable pCP early-rootfs boot contract.

The build is pinned to Linux 6.12.67 because pCP 11.1.0 uses 6.12.67.

## Build model

    ophub/unifreq 6.12.y
             +
    ophub stable 6.12 baseline
             +
    pCP-N1 SquashFS boot overrides
             |
             v
       6.12.67-pcp-n1

The workflow downloads ophub's current `config-6.12` at build time,
applies `config/pcp-squashfs-boot.fragment`, and passes the resulting
complete config to the ophub Action using `kernel_config`.

## What this version guarantees at build time

The final config must have the declared early-rootfs chain built in (`=y`):

- ARM64 / Meson
- initrd
- devtmpfs
- block layer / loop
- SquashFS and common decompression formats
- EXT4
- FAT/MSDOS/VFAT
- MMC block + Meson GX/MX SDIO
- SCSI + SCSI disk
- USB/XHCI/EHCI
- USB storage/UAS
- DWC3 + Meson G12A glue
- Meson GXL USB2 PHY
- proc/sysfs/tmpfs
- ELF
- initrd compression formats

This is a **static kernel-side guarantee** that the kernel contains the
pieces needed to access and mount a SquashFS root filesystem on the N1
through the supported storage paths.

It does NOT yet prove that the pCP 11.1.0 initrd uses the expected device,
partition, filesystem path, boot arguments, or extension layout. Those are
the next-stage pCP image analysis items.

## Deliberate separation

This version does not create `N1-KERNEL-<KVER>.tcz` yet.

The runtime modules will be handled after the actual pCP 11.1.0 image
is inspected. The current stage is only to establish the kernel-side
early-rootfs contract.

## Important

The workflow fails if any required early-rootfs symbol is not `=y`.
