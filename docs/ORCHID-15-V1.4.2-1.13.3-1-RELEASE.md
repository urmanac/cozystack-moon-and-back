# ORCHID-15 (v1.4.2-1.13.3-1) Release Notes

## Overview
The **ORCHID-15** release upgrades the HailoRT AI accelerator drivers to **v5.3.0**. This is a critical update for users of the **Raspberry Pi AI HAT+** (Hailo-10H), as the previous v4.x drivers only supported the Hailo-8 series.

## Key Changes
1. **HailoRT v5.3.0 Upgrade:**
   - Updated the HailoRT extension to version 5.3.0.
   - This version includes support for the `hailo1x_pci` module required by Hailo-10H.
2. **Flexible Extension Overrides:**
   - Improved the `gen-profiles.sh` script to allow overriding extension images via environment variables (e.g., `HAILORT_IMAGE=...`). This facilitates easier testing of custom extension builds.
3. **Module Name Transition:**
   - Users of Hailo-10H should now use the `hailo1x_pci` module in their Talos machine configuration.

## Usage for Hailo-10H
To enable the Hailo-10H driver on a Talos node, add the following to your machine configuration:

```yaml
machine:
  kernel:
    modules:
      - name: hailo1x_pci
```

*Note: For Hailo-8 series, the module name remains `hailo_pci`.*

## Artifacts

### OCI Images
**Talos Installer (Upgrades)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.3`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.3-rpi5`

**Matchbox (Netboot)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.3-cozy-v1.4.2-1`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.3-cozy-v1.4.2-1-rpi5`

### Flashable Metal Images
- CM4: `talos-metal-arm64-spin-hailort-talos-v1.13.3-cozy-v1.4.2-1.raw.xz`
- CM5: `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.3-cozy-v1.4.2-1.raw.xz`
