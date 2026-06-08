# ORCHID-15 (v1.4.2-1.13.3-1) - HailoRT 5.3.0 Upgrade Plan

## Problem
The current HailoRT drivers (v4.x) included in the Talos images only support Hailo-8 series hardware. The newer Hailo-10H (used in the Raspberry Pi AI HAT+) requires HailoRT v5.x drivers, specifically the `hailo1x_pci` module.

## Strategy
1. **GitHub Issue:** Create an issue on `urmanac/cozystack-moon-and-back` to track this (Done: #80).
2. **Version Update:** Bump project version to `v1.4.2-1.13.3-1` to trigger a new release build.
3. **Extensions Patch:** Provide a one-line patch for the `siderolabs/extensions` repository to update `HAILORT_VERSION` to `5.3.0`.
4. **CozyStack Patch:** Update the `spin-hailort` variant to use the updated extension.
5. **Documentation:** Update usage instructions to reflect the new module name (`hailo1x_pci`).

## Execution
- [x] Create GitHub issue #80.
- [x] Update `VERSION` file.
- [ ] Create `patches/12-hailort-v5.3.0-extension.patch` for the extensions repo.
- [ ] Update `patches/08-arm64-spin-hailort.patch` to support versioned overrides.
- [ ] Update `docs/LAVENDER-11-V1.4.0-RELEASE.md` or create a new release doc for v1.4.2-1.13.3-1.

## Build Testing
The changes will be tested in a Pull Request. We expect the `build-talos-images.yml` workflow to pass, assuming the 5.3.0 extension image is available in the registry.
