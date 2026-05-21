# LAVENDER-11: ARM64 CozyStack v1.4.0 Release

**Date:** 2026-05-21  
**Target Upstream:** v1.4.0  
**Status:** In Progress

## Mission
Upgrade the ARM64 CozyStack image pipeline to track the latest upstream v1.4.0 release.

## Notable Upstream Changes (v1.4.0)
- Talos v1.13.0
- cert-manager v1.20.2
- Cilium v1.19.3
- NVIDIA GPU Operator v26.3.1
- etcd-operator v0.4.3
- KubeVirt v1.8.2
- cozy-proxy v0.3.0
- linstor-csi v1.10.6
- New: HAMi v2.8.1 and ouroboros v0.7.2 packages

## Validation Results (Local)
- All 7 patches applied cleanly to a clean v1.4.0 upstream clone.
- Patch 01 (spin-tailscale): PASS
- Patch 02 (makefile-arch): PASS
- Patch 03 (spin-only): PASS
- Patch 04 (default-arm64): PASS
- Patch 06 (kubeovn-retag): PASS
- Patch 07 (skip-amd64-builds): PASS

## Release Orchestration Steps
1. [x] Create release branch `release/v1.4.0`.
2. [x] Update default `cozystack_commit` in `.github/workflows/build-talos-images.yml` to `v1.4.0`.
3. [ ] Push branch and verify CI build.
4. [ ] Merge to `main`.
5. [ ] Tag `v1.4.0` to trigger full asset release.
6. [ ] Verify published OCI images and raw disk assets.

## CI Configuration Updates
The following updates were made to `.github/workflows/build-talos-images.yml`:
- `cozystack_commit` default changed from `v1.3.3` to `v1.4.0`.

---
*Follow-up tasks:*
- Monitor CI for `build-talos-images.yml` completion.
- Verify `docs/LATEST-BUILD.md` is updated by CI.
- Execute tag push upon successful merge.
