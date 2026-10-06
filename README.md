# S905-pCP-kernels v0.3.0 — Route B

Route B uses `unifreq/linux-6.12.y` as the Phicomm N1 hardware/kernel
baseline, then adds piCorePlayer runtime requirements with a small Kconfig
fragment.

Target: Phicomm N1 / Amlogic S905D / Meson GXL / ARM64.

Normal N1 DTB:
`meson-gxl-s905d-phicomm-n1.dtb`

The alternate DMA-threshold DTB is intentionally not selected in v0.3.0.

## Build flow

unifreq/linux-6.12.y -> defconfig -> n1-pcp.fragment -> olddefconfig
-> Image + `make dtbs` + modules -> `.work/package/`

The DTB is built with `make dtbs`; this avoids the previous incorrect bare
top-level DTB target.

## U-Boot

U-Boot is not rebuilt here. Keep using the known-good N1 U-Boot from the
ophub/unifreq ecosystem, such as `u-boot-n1.bin`.

## First-stage target

U-Boot -> Linux -> pCP init/initrd -> Ethernet -> DHCP -> SSH -> ALSA
-> USB DAC -> Squeezelite -> LMS -> playback.

HDMI/DRM is not the first-stage blocker.

## GitHub Actions

Run:
`Actions -> Build S905 pCP kernel - Route B -> Run workflow`

Defaults:
- kernel branch: `6.12.y`
- kernel repo: `https://github.com/unifreq/linux-6.12.y.git`

The result is a kernel package, not a complete bootable pCP image.


## GitHub Actions execution model

The workflow does **not** depend on the executable bit stored in the ZIP or
local filesystem. GitHub Actions explicitly runs:

```sh
chmod 0755 scripts/build.sh
bash -n scripts/build.sh
bash ./scripts/build.sh
```

The workflow also sets `defaults.run.shell: bash`. This makes the actual
runner behavior deterministic even if the repository was prepared or
transferred through an environment that did not preserve Unix executable
permissions.

## Scope

v0.3.0 does not yet build the complete pCP initrd/rootfs, Squeezelite
extensions, N1 image, U-Boot, or DMA-threshold DTB variant.
