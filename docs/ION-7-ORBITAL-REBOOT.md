# ION-7: Orbital Reboot (0.38 -> 1.3.3)

Date: 2026-05-15

## Mission
Revive the ARM64 image pipeline for CozyStack using a modern stable upstream release, while preserving the two-extension-variant deployment model needed for real Raspberry Pi cluster operation.

## What Changed Since 0.38 (Critical Findings)
1. Upstream architecture changed significantly between the 0.38 series and 1.3.x.
2. Talos image build logic moved from packages/core/installer to packages/core/talos.
3. packages/core/installer now builds and publishes cozystack-operator (not Talos assets).
4. Existing patches in this repo were targeting removed paths in packages/core/installer/hack and therefore failed with:
   - gen-profiles.sh: No such file or directory
   - gen-versions.sh: No such file or directory
5. Upstream now has stable release lines (for example release-1.2 and release-1.3), so pinning to a stable tag is preferable to following main for reproducible rebuilds.

## Verified Upstream Baseline
1. Selected baseline: v1.3.3 (stable, non-prerelease).
2. Upstream tag exists and resolves correctly.
3. Clean validation worktree used for patch checks: /tmp/cozystack-v1.3.3-check.

## Project Decisions Confirmed
1. Keep both Talos extension variants:
- spin-only for most nodes.
- spin-tailscale for the dedicated subnet-router node.
2. Pin workflow default to v1.3.3.
3. Include cozystack-operator image publishing in this repo's build bundle.
4. Use ARM64 matchbox base image tag: v0.11.0-310-g77aedbd0-arm64.
5. Follow patch policy strictly: generate patches from edited source with git diff, never hand-edit patch files in place.

## Concrete Repo Updates Applied
1. Workflow updated in [.github/workflows/build-talos-images.yml](.github/workflows/build-talos-images.yml):
- Default ref input now v1.3.3.
- Added build target option image-operator.
- Changed references from installer/hack scripts to talos/hack scripts.
- Talos build section now operates under packages/core/talos.
- Operator image build integrated via packages/core/installer image-operator target.
- ARM64 validation now includes operator image existence and architecture checks.
2. Patch paths aligned to v1.3.3 Talos layout:
- [patches/01-arm64-spin-tailscale.patch](patches/01-arm64-spin-tailscale.patch)
- [patches/02-makefile-architecture-variables.patch](patches/02-makefile-architecture-variables.patch)
- [patches/03-arm64-spin-only.patch](patches/03-arm64-spin-only.patch)
3. Validation helper scripts updated for moved paths:
- [validate-patch.sh](validate-patch.sh)
- [validate-complete.sh](validate-complete.sh)

## Patch Validation Status
Validated against clean upstream v1.3.3 worktree:
1. 01-arm64-spin-tailscale.patch: PASS (git apply --check).
2. 02-makefile-architecture-variables.patch: PASS (git apply --check).
3. 03-arm64-spin-only.patch: PASS (git apply --check).

## Functional Impact of the New Patch Set
1. Talos profile generation switches architecture from amd64 to arm64.
2. Talos profile generation injects Spin (and optionally Tailscale) extension image references.
3. Talos build targets use arm64 asset names in Makefile and matchbox Dockerfile copies.
4. Matchbox image base updated to a recent ARM64-capable upstream tag.
5. Workflow builds operator image as part of the modern CozyStack packaging model.

## Remaining Work Before Merge/Push
1. Run the updated GitHub Actions workflow once for each variant and inspect pushed image manifests:
- spin-only
- spin-tailscale
2. Confirm published operator image coordinates and tags match intended consumption paths.
3. Validate end-to-end CM4 bootstrap path with spin-only first, then enable tailscale variant on one node.
4. Optionally clean old documentation references still pointing to legacy installer/hack locations.

## Why This Matters for CM4 Bring-Up
1. The old 0.38 assumptions no longer represent upstream build topology.
2. Without this migration, ARM64 patching fails before any build starts.
3. With these updates, the repo again aligns with its core purpose: producing publishable ARM64 CozyStack images for real hardware clusters.
