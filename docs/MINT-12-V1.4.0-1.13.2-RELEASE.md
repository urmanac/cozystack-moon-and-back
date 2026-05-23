# MINT-12: ARM64 CozyStack v1.4.0-1.13.2 Release

**Date:** 2026-05-23
**Target Upstream:** v1.4.0
**Talos Version:** v1.13.2
**Status:** In Progress

## Mission
Upgrade the ARM64 CozyStack image pipeline to Talos v1.13.2 and introduce the `spin-hailort` variant for AI accelerator support on Raspberry Pi CM4/CM5.

## Notable Changes
- **Talos Upgrade:** Bumped from v1.13.0 to v1.13.2.
- **New Variant:** `spin-hailort` added, containing both `spin` (WebAssembly) and `hailort` (Hailo AI driver) extensions.
- **Bootability Fix:** Added `board: rpi_generic` to the ARM64 metal profile and included the `vc4` extension. This ensures that the generated `.raw.xz` images include the necessary Raspberry Pi firmware and are bootable out-of-the-box on CM4.
- **Versioning:** Introduced composite tagging (e.g., `v1.4.0-1.13.2`) to track both CozyStack and Talos versions independently.

## Extension Variants
- `spin-only`: Spin runtime only.
- `spin-tailscale`: Spin runtime + Tailscale subnet router.
- `spin-hailort`: Spin runtime + HailoRT AI accelerator drivers.

## Validation Results (Local)
- Patch 08 (spin-hailort): PASS (verified structure)
- Workflow Syntax: PASS
- Tag Parsing Logic: PASS (verified against regex)

## Artifacts (Expected)
- `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.2`
- `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-1.13.2-cozy-v1.4.0`
