# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-17 05:31:24 UTC  
**Talos Version:** `v1.11.5`  
**CozyStack Commit:** `${COZYSTACK_COMMIT:-'unknown'}`  
**Build Target:** `assets`  
**Total Assets:** 6  

**Asset Digests:**
- **Kernel:** `sha256:2777e9bd8d98736ba632fa8cb34ff9f7815779e806d52a5379da872213bb1da8`
- **Initramfs:** `sha256:df16c0e2460fea951c2f4755cde07d86602401e2b0c06e7ba0b375e2f71e6f9f`

**Container Image:**
```bash
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable
```

**Complete Asset Extraction:**
```bash
# Extract complete ARM64 asset array with validation
mkdir -p /opt/cozystack-assets
docker create --name temp-extract ghcr.io/urmanac/talos-cozystack-demo:demo-stable
docker cp temp-extract:/assets/. /opt/cozystack-assets/
docker rm temp-extract

# Verify checksums
cd /opt/cozystack-assets/talos/arm64
sha256sum -c checksums.sha256

# View build report
cat validation/build-report.txt
```

**For AWS Bastion Matchbox Setup:**
```bash
# Extract boot assets for matchbox
docker create --name temp-matchbox ghcr.io/urmanac/talos-cozystack-demo:demo-stable
docker cp temp-matchbox:/assets/talos/arm64/boot/. /opt/matchbox/assets/
docker rm temp-matchbox
```
