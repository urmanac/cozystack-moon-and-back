# THYME-20 (v1.5.1-1.13.5-4) Release Notes

## Overview
The **THYME-20** release revision `v1.5.1-1.13.5-4` is a stabilization release that resolves container startup format failures on ARM64 nodes. 

Previously, when the operator packaged individual system components, generated `.tag` files containing references to custom ARM64-compiled sub-images (such as `grafana-dashboards` or clickhouse backups) were discarded by the CI/CD pipeline pipeline stages. This caused the packaged charts to fall back to upstream default AMD64-compiled container images, leading to container startup errors like:
```
exec /usr/bin/darkhttpd: exec format error
```

This release preserves and serializes tag files across all package build and assembly stages, guaranteeing that the cluster retrieves fully ARM64-compatible sub-images from our custom registry.

## Key Changes
1. **Preserved Tag Files Across Build Stages**:
   - Updated `.github/workflows/release-talos-assets.yml` to archive the `images/` directory `.tag` files (which specify the custom OCI registry references and digests) along with `values.yaml`.
   - Updated the restore step to write both values and tags back into the fresh workspace clone before building and publishing the `cozystack-packages` OCI collection artifact.
2. **Fixed `grafana-dashboards` Boot Mismatch**:
   - Resolves `exec format error` crashes in the `cozy-grafana-operator/grafana-dashboards` pod by properly routing the tag references to the ARM64-built container digest on our registry.

---

## Upgrade / Install Instructions

To upgrade CozyStack to this release version, run the following Helm command:

```bash
# Upgrade CozyStack and point the operator to our custom ARM64 registry and package collection
helm upgrade --install cozystack oci://ghcr.io/cozystack/cozystack/cozy-installer \
  --version 1.5.1 \
  --namespace cozy-system \
  --create-namespace \
  --set cozystackOperator.image=ghcr.io/urmanac/cozystack-assets/cozystack-operator@sha256:IMAGE_DIGEST_OPERATOR \
  --set cozystackOperator.platformSourceUrl=oci://ghcr.io/urmanac/cozystack-assets/cozystack-packages \
  --set cozystackOperator.platformSourceRef=digest=sha256:IMAGE_DIGEST_PACKAGES
```

> [!NOTE]
> Replace `IMAGE_DIGEST_OPERATOR` and `IMAGE_DIGEST_PACKAGES` with the actual OCI digests dynamically resolved by the GitHub release workflow.

---
*Verified by Release Provenance Rubric*
