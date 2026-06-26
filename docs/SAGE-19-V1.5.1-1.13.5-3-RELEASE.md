# SAGE-19 (v1.5.1-1.13.5-3) Release Notes

## Overview
The **SAGE-19** release revision `v1.5.1-1.13.5-3` is a critical revision that fixes the values-yaml nesting bug in the package generation workflows. This bug caused the compiled CozyStack operator and packages to ignore registry override settings and fallback to upstream amd64 images, resulting in CNI `exec format error` crash loops (such as the `config` init container of the `cilium` daemonset).

This revision ensures that the packages are correctly compiled referencing the custom ARM64 GHCR registry (`ghcr.io/urmanac/cozystack-assets`), and it adds full cryptographic OCI digests for all release images to allow users to lock and verify their cluster installations.

## Key Changes
1. **Fixed Values Overwrite Nesting Bug**:
   - Corrected the copy target inside `.github/workflows/build-talos-images.yml` and `.github/workflows/release-talos-assets.yml`. The build downloaded the `values-archive` artifact and unzipped it, then copied files using `cp -r values-archive-download/* cozystack-upstream/packages/`.
   - Because `values-archive` contains the `packages/` directory hierarchy, this nested the files into `cozystack-upstream/packages/packages/...`, preventing them from overwriting the actual package directories.
   - Updated the copy target to `cozystack-upstream/`, which aligns directories correctly and replaces values overrides as intended.
2. **Fixed Talos Variant Image Tagging**:
   - Patched `hack/patch-talos.sh` to apply `11-fix-tagging-logic.patch` to all variants (`spin-hailort`, `spin-tailscale`, `spin-only`).
   - This ensures the built Talos installers and Matchbox images are tagged with the specific CozyStack release tag (`v1.5.1-1.13.5-3`) rather than falling back to `dev`.
3. **Dynamic OCI Digest Integration**:
   - Upgraded the release workflow to resolve the exact SHA256 digests of all pushed OCI images using crane and inject them directly into the published GitHub Release notes.

---

## Upgrade / Install Instructions

To install or upgrade CozyStack to this release version, run the following Helm command:

```bash
# Upgrade CozyStack and point the operator to our custom ARM64 registry and package collection
helm upgrade --install cozystack oci://ghcr.io/cozystack/cozystack/cozy-installer \
  --version 1.5.1 \
  --namespace cozy-system \
  --create-namespace \
  --set cozystackOperator.image=ghcr.io/urmanac/cozystack-assets/cozystack-operator@sha256:73047678e4e8e2ac021fa91b7e99a3496c6559b94578470e16d713870c978255 \
  --set cozystackOperator.platformSourceUrl=oci://ghcr.io/urmanac/cozystack-assets/cozystack-packages \
  --set cozystackOperator.platformSourceRef=digest=sha256:dec6a6f764c65d54d71c24b579903143efccc86a59f389e7bdb0e2c2b1034e36
```

> [!IMPORTANT]
> The above installer parameters are locked to the specific cryptographic OCI digests of this release. This guarantees that your installation pulls verified and architecture-compatible packages.

---

## OCI Images (Digest-Locked)

### Operator & Packages
- **Operator:** `ghcr.io/urmanac/cozystack-assets/cozystack-operator@sha256:73047678e4e8e2ac021fa91b7e99a3496c6559b94578470e16d713870c978255`
- **Packages Collection:** `ghcr.io/urmanac/cozystack-assets/cozystack-packages@sha256:dec6a6f764c65d54d71c24b579903143efccc86a59f389e7bdb0e2c2b1034e36`

### Variant: spin-hailort (Raspberry Pi AI HAT+)
- **Talos Installer (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos@sha256:0a195c2da186e475cfa845e81d3000d21f6e7c044117be414ed5b501aa8ddc6a`
- **Talos Installer (CM5):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos@sha256:c64983a2af6940c295c03e43bf6cfc2810b075c6d85255f8e475bcf4da6e52c2`
- **Matchbox (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox@sha256:c4021afa1dc5494a643390e2d3871910ed5930e275aa66652820abd9386820a3`
- **Matchbox (CM5):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/matchbox@sha256:d7e90238a8eac8cc12cb405f05bb077b5f92a03e773b9048baf7de7d9d2fed4a`

### Variant: spin-tailscale (Tailscale Integration)
- **Talos Installer (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos@sha256:33d9eed04d7df425df17819837cef1b7617d48f706f793e77857ea4076d4b192`
- **Matchbox (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/matchbox@sha256:be208bf395aa25447867397060026e3d886aa731362fbe48803379b2ef9057f7`

### Variant: spin-only (Base OS)
- **Talos Installer (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos@sha256:57e5a8fe35c42a8508d37c2e34f206de114bf7917a34e4f28d8c15afdd8a0f86`
- **Matchbox (CM4):** `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/matchbox@sha256:be2a3ceb9a48c52ef88e54aaf7d9b0599897b07a321376386425142d3f9b3129`

---

### Flashable Metal Images (spin-hailort variant)
- **CM4:** `talos-metal-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1.raw.xz`
- **CM5:** `talos-metal-rpi5-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1.raw.xz`

### Specialized RPi5 Netboot Assets (spin-hailort variant)
- **Kernel:** `talos-kernel-rpi5-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1`
- **Initramfs:** `talos-initramfs-rpi5-arm64-spin-hailort-talos-v1.13.5-cozy-v1.5.1.xz`

---
*Verified by Release Provenance Rubric*
