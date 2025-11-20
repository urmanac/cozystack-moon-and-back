# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-20 04:26:36 UTC  
**Talos Version:** `v1.11.5`  
**CozyStack Commit:** `pending`  
**Build Target:** `upstream-images`  
**Total Assets:** 2  

## Asset Digests

| Asset | Digest |
|-------|--------|
| **Kernel** | `pending` |
| **Initramfs** | `pending` |

## Container Images

Two variants are built for different use cases:

### spin-tailscale (Full Stack)
Includes Spin runtime + Tailscale networking for complete demo environment.

```bash
docker pull ghcr.io/urmanac/talos-cozystack-spin-tailscale:demo-stable
```

### spin-only (Minimal)
Includes only Spin runtime for lightweight deployments.

```bash
docker pull ghcr.io/urmanac/talos-cozystack-spin-only:demo-stable
```

## Asset Extraction

Extract complete ARM64 asset bundle with validation:

```bash
# Create asset directory
mkdir -p /opt/cozystack-assets

# Extract from spin-tailscale image
docker create --name temp-extract ghcr.io/urmanac/talos-cozystack-spin-tailscale:demo-stable
docker cp temp-extract:/assets/. /opt/cozystack-assets/
docker rm temp-extract

# Verify integrity
cd /opt/cozystack-assets/talos/arm64
sha256sum -c checksums.sha256

# View build report
cat validation/build-report.txt
```

