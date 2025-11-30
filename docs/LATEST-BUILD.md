# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-30 16:07:06 UTC  
**Talos Version:** `v1.11.5`  
**CozyStack Commit:** ``  
**Build Target:** `upstream-images`  
**Total Assets:** 2  

## Asset Digests

| Asset | Digest |
|-------|--------|
| **Kernel** | `'not found'` |
| **Boot Loader** | `'not found'` |

## Container Images

Two variants are built for different use cases:

### talos/cozystack-spin-tailscale (Full Stack)
Includes Spin runtime + Tailscale networking for complete demo environment.

```bash
docker pull ghcr.io/urmanac/talos/cozystack-spin-tailscale:demo-stable
```

### talos/cozystack-spin-only (Minimal)
Includes only Spin runtime for lightweight deployments.

```bash
docker pull ghcr.io/urmanac/talos/cozystack-spin-only:demo-stable
```

## Asset Extraction

Extract complete Talos installer assets:

```bash
# Create local assets directory
mkdir -p ./cozystack-assets

# Extract from talos/cozystack-spin-tailscale image (recommended)
docker create --name temp-extract ghcr.io/urmanac/talos/cozystack-spin-tailscale:demo-stable
docker cp temp-extract:/. ./cozystack-assets
docker rm temp-extract

# Key assets are located at:
# ./cozystack-assets/usr/install/arm64/vmlinuz.efi
# ./cozystack-assets/usr/install/arm64/systemd-boot.efi
# ./cozystack-assets/usr/bin/installer
```
