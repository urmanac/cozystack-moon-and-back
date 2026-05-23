Built: 2026-05-23 19:36:12 UTC

- Talos version: `v1.13.2`
- CozyStack release: `v1.4.0`
- Build target: `image`
- Extracted asset count: `4`

## Asset Digests

| Asset | Digest |
|-------|--------|
| Kernel | `2ca630b49bf174acf82a4461f924c6310a35d9e8f05c56baeec99d08f3b21e11` |
| Boot Loader | `a01efae6b41b0df27c8057310c6c8dcd9b349bdd3c2dfb1848da3dcb99cba8d2` |

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
