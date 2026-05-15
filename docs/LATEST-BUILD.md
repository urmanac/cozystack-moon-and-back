# Latest CozyStack ARM64 Talos Build

**Built:** 2026-05-15 19:17:49 UTC
**Talos Version:** `v1.13.2`
**CozyStack Release:** `v1.3.3`
**Build Target:** `upstream-images`
**Total Assets:** 2

## Asset Digests

| Asset | Digest |
|-------|--------|
| **Kernel** | `not available` |
| **Boot Loader** | `not available` |

## Container Images

Two variants are built for different use cases:

### talos/cozystack-spin-tailscale (Full Stack)
Includes Spin runtime + Tailscale networking for complete demo environment.

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale:latest
```

### talos/cozystack-spin-only (Minimal)
Includes only Spin runtime for lightweight deployments.

```bash
docker pull ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only:latest
```

### CozyStack Operator

```bash
docker pull ghcr.io/urmanac/cozystack-assets/cozystack-operator:latest
```

## Asset Extraction

Extract complete Talos installer assets:

```bash
# Create local assets directory
mkdir -p ./cozystack-assets

# Extract from talos/cozystack-spin-tailscale image (recommended)
docker create --name temp-extract ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale:latest
docker cp temp-extract:/. ./cozystack-assets
docker rm temp-extract

# Key assets are located at:
# ./cozystack-assets/usr/install/arm64/vmlinuz.efi
# ./cozystack-assets/usr/install/arm64/systemd-boot.efi
# ./cozystack-assets/usr/bin/installer
```
