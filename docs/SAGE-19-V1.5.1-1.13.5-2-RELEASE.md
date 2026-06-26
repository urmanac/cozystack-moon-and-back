# SAGE-19 (v1.5.1-1.13.5-2) Release Notes

## Overview
The **SAGE-19** release revision `v1.5.1-1.13.5-2` upgrades CozyStack to **v1.5.1** and Talos Linux to **v1.13.5**, while resolving the registry override packaging issue that caused CNI pods (like Cilium init containers) to experience `exec format error` (due to pulling default amd64-only upstream images).

This release also introduces a stricter, context-aware patch validation suite and restores the `kubeovn` target in GHA matrix groups to maintain package catalog consistency.

## Key Changes
1. **Resolved CNI Init Container Exec Format Errors**:
   - Fixed a path mismatch bug in the GitHub Actions workflows (`build-talos-images.yml` and `release-talos-assets.yml`) where the generated `values.yaml` registry overrides were archived at the wrong path (`../values-archive` instead of the workspace folder `values-archive`).
   - This mismatch previously resulted in empty upload artifacts, causing the packaging stage (`build-cozystack-operator` / `installer`) to bundle default charts referencing the upstream registry `ghcr.io/cozystack/cozystack` instead of our custom ARM64 registry `ghcr.io/urmanac/cozystack-assets`.
   - The fix ensures the operator properly configures all CNI deployment manifests to target our local custom ARM64 images.
2. **CozyStack upstream v1.5.1 Upgrade**:
   - Pulled the latest upstream minor version release of CozyStack, incorporating upstream fixes and enhancements.
3. **Kubeovn Build Target Alignment**:
   - Restored `packages/system/kubeovn` to the workflow matrix `system-net` DIRS build and archive list. Since patch `06-kubeovn-manifest-list-retag.patch` adds `kubeovn` back to retag/copy it, this alignment allows the package catalog validator to pass.
4. **Stricter Patch Validation Suite**:
   - Refactored `validate-patch.sh` to validate patches inside their correct target contexts (mutually exclusive Talos variants: `spin-only`, `spin-hailort`, `spin-tailscale`, and Sidero extensions/pkgs repos) and fail the pipeline immediately if any patch fails.
   - Refactored `validate-complete.sh` to delegate checks directly to `validate-patch.sh`, eliminating duplicate validation scripting.

## Strategy & Validation Summary
All upgrade plans are integrated into `main` and validated locally:
- **Version bump**: Bumped `VERSION` file to `v1.5.1-1.13.5-2`.
- **Local test suite**: All check patches, nested patches, catalog consistency, and workflow validations pass cleanly under `./validate-complete.sh`.

## Usage for Hailo-10H
To enable the Hailo-10H driver on a Talos node, add the following to your machine configuration:

```yaml
machine:
  kernel:
    modules:
      - name: hailo1x_pci
```

## Artifacts

### OCI Images
**Talos Installer (Upgrades)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.5`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:v1.13.5-rpi5`

**Matchbox (Netboot)**
- Generic (CM4): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.5-cozy-v1.5.1`
- RPi5 (CM5): `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox:talos-v1.13.5-cozy-v1.5.1-rpi5`

**Dashboard (ARM64)**
- Frontend UI: `ghcr.io/urmanac/cozystack-assets/cozystack-ui:v1.5.1`
- Token Proxy: `ghcr.io/urmanac/cozystack-assets/token-proxy:v1.5.1`

### Flashable Metal Images
- CM4: `talos-metal-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1.raw.xz`
- CM5: `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1.raw.xz`

## Future Roadmap & Plans
1. **Immutable Releases**: Transition the release pipeline to strictly enforce immutability of release tags (e.g. preventing local force-pushing over existing version tags).
2. **Annotated & Cryptographically Signed Tags**: Add annotated and signed tag validation to the release flow to guarantee identity provenance for custom sovereign builds.
