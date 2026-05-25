# NUTMEG-13 (v1.4.0-1.13.2-1) Release Notes

## Overview
The **NUTMEG-13** release represents a major stabilization of the Cozystack Talos image build process, specifically addressing the requirements for multi-board architecture support (CM4 and CM5).

We have eliminated "vibes-based" releases by instituting a strict CI provenance rubric. This ensures that a release tag mathematically guarantees the successful publication of all 31+ required OCI and metal images to our artifact registry.

## Key Changes
1. **Specialized RPi5 Support:**
   - Introduced `rpi_5` firmware overlay to the `metal` and `installer` profiles.
   - Introduced specialized `matchbox` images explicitly targeted for RPi5 netbooting, containing the `initramfs-rpi5` and `kernel-rpi5` profiles.
2. **Release Provenance Rubric:**
   - Every release is now validated by a strict rubric (`05-release-provenance.sh`), which confirms the successful build, tagging, and publication of all Cozystack and Talos images.
3. **CI Orderly Release Pipeline:**
   - Modified CI to allow revision tagging (e.g., `-1`).
   - Defined strict rules via the `talos-release-manager` skill to ensure tags are only cut *after* the `main` branch cache is successfully seeded.

## Artifacts

### OCI Images
**Talos Installer (Upgrades)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.2`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.2-rpi5`

**Matchbox (Netboot)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.2-cozy-v1.4.0-1`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.2-cozy-v1.4.0-1-rpi5`

**Cozystack Packages**
- Operator: `ghcr.io/urmanac/cozystack-assets/cozystack-operator:v1.4.0-1.13.2-1`

### Flashable Metal Images
- CM4: `talos-metal-arm64-spin-hailort-talos-v1.13.2-cozy-v1.4.0-1.raw.xz`
- CM5: `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.2-cozy-v1.4.0-1.raw.xz`

### RPi5 Netboot Assets
- Kernel: `talos-kernel-rpi5-arm64-spin-hailort-talos-v1.13.2-cozy-v1.4.0-1`
- Initramfs: `talos-initramfs-rpi5-arm64-spin-hailort-talos-v1.13.2-cozy-v1.4.0-1.xz`
