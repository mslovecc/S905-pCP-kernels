# Phicomm N1 board profile

## Hardware

- Board: Phicomm N1
- SoC: Amlogic S905D
- Meson family: GXL

## Device tree

Use the upstream:

```text
arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dts
```

Build output:

```text
arch/arm64/boot/dts/amlogic/meson-gxl-s905d-phicomm-n1.dtb
```

No copied DTB from Armbian/ophub is used.

## First validation

The first image is intended to boot from USB using the existing known-good N1
U-Boot. Validation should concentrate on:

1. USB boot
2. Linux kernel startup
3. HDMI connector detection
4. 1920x1080 display output
5. Tiny Core initrd/rootfs startup
6. USB storage and Ethernet
7. `/proc/device-tree/model` reports `Phicomm N1`

The image repository will later select this board profile by manifest.
