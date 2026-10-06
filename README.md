# S905-pCP-kernels v0.3.1

Phicomm N1 (Amlogic S905D / Meson GXL) kernel workflow for piCorePlayer.

## Why v0.3.1 changed the architecture

v0.3.0 tried to do:

    git clone --branch 6.12.y https://github.com/unifreq/linux-6.12.y.git

and failed because `6.12.y` is a kernel **series selector**, not a Git branch
that should be passed directly to `git clone`.

ophub resolves the repository and kernel series itself. Its documented GitHub
Action interface is:

    uses: ophub/amlogic-s9xxx-armbian@main
    with:
      build_target: kernel
      kernel_source: unifreq
      kernel_version: 6.12.y
      kernel_auto: true

The v0.3.1 workflow therefore delegates source resolution, compilation,
DTB generation, module installation and packaging to the ophub Action.

## Configuration strategy

v0.3.1 deliberately uses:

    config_flavor: stable

instead of feeding our old small `n1-pcp.fragment` through `kernel_config`.

This distinction is important: ophub's `kernel_config` input expects a
versioned configuration template such as `config-6.12`, not a merge fragment.

The current ophub stable 6.12 configuration already contains the key
first-stage requirements we have been targeting, including:

- ARM64 / Meson platform support
- initrd and common filesystem support
- USB XHCI/EHCI/DWC3 and USB storage/UAS
- USB audio (`SND_USB_AUDIO=m`)
- Amlogic Meson audio drivers
- module support

The authoritative template is maintained in ophub/kernel.

## Patch strategy

`kernel-patch/6.12.y/` is intentionally empty in v0.3.1.

`auto_patch` is disabled. We will only add a patch after a concrete build
or N1 runtime test proves that it is necessary. This avoids carrying
speculative patches on top of the unifreq hardware baseline.

## First-stage target

    U-Boot
      -> Linux
      -> pCP init
      -> Ethernet / DHCP
      -> SSH
      -> ALSA
      -> USB DAC
      -> Squeezelite
      -> LMS playback

HDMI/DRM is not a first-stage blocker.

## GitHub Actions

There is no local `build.sh` in v0.3.1. The build is intentionally performed
by the ophub GitHub Action/container so that kernel-series resolution and the
actual compilation environment match ophub's workflow model.
