Built: 2026-05-15 20:47:01 UTC

- Talos version: `v1.13.2`
- CozyStack release: `v1.3.3`
- Build target: `upstream-images`
- Extracted asset count: `2`

## Asset Digests

| Asset | Digest |
|-------|--------|
| Kernel | `not available` |
| Boot Loader | `not available` |

## What This Build Contains

This page reflects the latest successful main branch build.

When build target is `upstream-images`:
- OCI images are published to GHCR.
- Bootable raw disk assets are not exported in this job.
- Kernel/boot-loader digests may be shown as `not available`.

Flashable raw disk images for Raspberry Pi CM4 are published from tagged releases.

Tagged release artifacts:
- `metal-arm64.raw.xz`: flashable bare-metal image for SD/eMMC/NVMe.
- `nocloud-arm64.raw.xz`: image intended for VM/cloud NoCloud metadata workflows.

## Container Images

Spin + Tailscale variant:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/talos:latest
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale/matchbox:latest
```

Spin-only variant:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/matchbox:latest
```

CozyStack operator:

```bash
docker pull ghcr.io/urmanac/cozystack-assets/cozystack-operator:latest
```

## Extract Assets From OCI

You can extract files from the Talos image tar layer if needed:

```bash
mkdir -p ./cozystack-assets
docker create --name temp-extract ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only/talos:latest
docker cp temp-extract:/. ./cozystack-assets
docker rm temp-extract
```
