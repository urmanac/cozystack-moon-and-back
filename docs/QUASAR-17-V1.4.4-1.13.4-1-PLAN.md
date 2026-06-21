# QUASAR-17 (v1.4.4-1.13.4-1) - CozyStack & Talos Upstream Sync Plan

## Overview
Cozystack upstream has released **v1.4.4** (focusing on dashboard stability and `talm` upgrades) and Talos upstream has released **v1.13.4** (with Linux kernel 6.18.34 and system package bumps). 

We need to sync our custom CozyStack Moon-and-Back images and the Sovereign OS Factory to target these versions. This sync ensures that our environment benefits from upstream fixes while preserving our custom ARM64 patches and the Hailo-10H (v5.3.0) driver module-signing capabilities.

## Strategy

1. **Version Configuration Update:**
   - Bump the version in the `VERSION` file to `v1.4.4-1.13.4-1` (CozyStack-Talos-Revision format).
   
2. **Upstream Version Alignment:**
   - Update default inputs and environment variables in [.github/workflows/build-talos-images.yml](file:///.github/workflows/build-talos-images.yml) to target CozyStack `v1.4.4` and Talos `v1.13.4`.
   - Update version declarations in the build scripts [hack/build-sovereign-os.sh](file:///hack/build-sovereign-os.sh) and [hack/build-hailort.sh](file:///hack/build-hailort.sh):
     - `TALOS_VERSION="v1.13.4"`
     - `EXT_TAG="v1.13.4"`
     - `PKGS_HASH="54ec9fc"` (corresponds to `v1.13.0-28-g54ec9fc` in Talos v1.13.4).

3. **Patch Conformance Validation:**
   - Run the local validation script (`./validate-complete.sh`) to ensure our patch files apply cleanly without syntax or context errors against the new upstream versions.
   
4. **CI Build and Deployment Testing:**
   - Push the upgrade changes to a feature branch (`feat/quasar-upgrade-v1.4.4-1.13.4`).
   - Monitor the GitHub Actions build-talos-images workflow runs.
   - Confirm that the Sovereign OS Factory compiles the `v1.13.4` kernel, tags correct artifacts (`installer`, `imager`, `hailort`, `drbd`, `zfs`), and builds/tags the final CozyStack installer and matchbox images.

5. **Release & Tagging Process:**
   - Merge the feature branch into `main`.
   - The merge will automatically trigger the Git tagging step and spawn the `release-talos-assets.yml` workflow, producing the flashable metal images.

## Execution Checklist

- [ ] Create local feature branch `feat/quasar-upgrade-v1.4.4-1.13.4`.
- [ ] Update [VERSION](file:///VERSION) to `v1.4.4-1.13.4-1`.
- [ ] Update default inputs in [.github/workflows/build-talos-images.yml](file:///.github/workflows/build-talos-images.yml).
- [ ] Update version variables and `PKGS_HASH` in [hack/build-sovereign-os.sh](file:///hack/build-sovereign-os.sh).
- [ ] Update version variables and `PKGS_HASH` in [hack/build-hailort.sh](file:///hack/build-hailort.sh).
- [ ] Run `./validate-complete.sh` to check patch compliance.
- [ ] Commit changes, push to branch, and monitor CI.
- [ ] Merge to `main` and watch release tagging.
