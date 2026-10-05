# tinycore-s905-kernel

Linux kernel build repository for the Tiny Core S905 family.

## First target

- Board: Phicomm N1
- SoC: Amlogic S905D
- Platform: Meson GXL
- DTB: `meson-gxl-s905d-phicomm-n1.dtb`
- Architecture: ARM64
- Kernel baseline: Linux 6.18.55 LTS

The first release intentionally uses an upstream Linux kernel and the upstream
Phicomm N1 device tree. Board-specific patches are kept separate under
`patches/` and are only added when required.

## Repository layout

```text
tinycore-s905-kernel/
├── boards/
│   └── meson-gxl/
│       └── phicomm-n1/
├── config/
│   └── n1.fragment
├── patches/
├── scripts/
│   └── build.sh
└── .github/workflows/
    └── build.yml
```

## Design rules

1. Build `Image`, not a distro-specific `zImage`.
2. Build the N1 DTB from the same kernel source tree.
3. Build modules from the same source/config as the kernel.
4. Keep boot-critical storage/filesystem support built in where practical.
5. Do not copy kernel modules from Armbian/ophub.
6. Release `Image + DTB + modules + config + build metadata + SHA256` together.
7. The image repository consumes this repository's release artifact; it does not
   compile or modify the kernel.

## First-stage boot strategy

The first N1 test can keep the known-good N1 U-Boot from the existing system.
Only kernel/DTB/modules are replaced. This isolates kernel/userspace problems
from U-Boot problems.

Expected kernel artifacts:

```text
Image
dtbs/amlogic/meson-gxl-s905d-phicomm-n1.dtb
modules/lib/modules/<kernel-release>/
config
build-info.txt
SHA256SUMS
```

## Local build

On an ARM64-capable Linux host with the required cross compiler:

```bash
./scripts/build.sh
```

The GitHub Actions workflow performs the same build in a clean Ubuntu runner.

## Versioning

Kernel source version and distro kernel localversion are defined in
`scripts/build.sh`. A release is immutable and should be consumed by exact
GitHub release tag and SHA256 from `tinycore-s905-image`.
