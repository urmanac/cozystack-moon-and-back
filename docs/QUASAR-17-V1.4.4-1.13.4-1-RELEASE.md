# QUASAR-17 (v1.4.4-1.13.4-1) Release Notes

## Overview
The **QUASAR-17** release upgrades upstream **CozyStack to v1.4.4** (focusing on dashboard stability and `talm` upgrades) and **Talos to v1.13.4** (incorporating Linux kernel 6.18.34).

This release stabilizes development builds by correcting overly aggressive CI triggers, aligns package dependencies for Custom Sovereign Kernel builds, and introduces stability fixes for the Hailo-Ollama gateway.

## Key Changes
1. **CozyStack upstream v1.4.4 Alignment**:
   - Pulled upstream fixes for dashboard stability.
2. **Talos upstream v1.13.4 Alignment**:
   - Upgraded default inputs to `v1.13.4` and pinned the sovereign kernel build to the Sidero pkgs tag `v1.13.0-28-g54ec9fc`.
3. **CI Trigger Stabilization**:
   - Fixed workflow triggers to run on any feature branch starting with `feat/` by using the `feat/**` glob pattern.
4. **Hailo-Ollama Proxy Stability**:
   - Fixed context saturation issues with `claude-code-proxy` and Tab Maestro by sanitizing nested JSON sequences, neutralizing escaped quotes, and adding context-trimming mechanisms to prevent 500s from caching overhead.

## Strategy & Validation Summary
All steps in the upgrade plan have been successfully executed and validated via local check scripts and remote GitHub CI:
- **Version bump**: Set to `v1.4.4-1.13.4-1` in `VERSION`.
- **Sovereign builds**: Patched to point to Talos `v1.13.4` with `PKGS_HASH="54ec9fc"`.
- **Trigger adjustment**: Standardized both `build-talos-images.yml` and `build-hailo-ollama.yml` push triggers.
- **Local test suite**: All check patches, syntax, and dependency checks passed cleanly.

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
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.4`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.4-rpi5`

**Matchbox (Netboot)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.4-cozy-v1.4.4-1`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.4-cozy-v1.4.4-1-rpi5`

### Flashable Metal Images
- CM4: `talos-metal-arm64-spin-hailort-talos-v1.13.4-cozy-v1.4.4-1.raw.xz`
- CM5: `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.4-cozy-v1.4.4-1.raw.xz`
