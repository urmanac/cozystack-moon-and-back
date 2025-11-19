# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-19 01:57:03 UTC  
**Talos Version:** ``  
**CozyStack Commit:** `${COZYSTACK_COMMIT:-'unknown'}`  
**Build Target:** ``  
**Total Assets:** N/A  

**Asset Digests:**
- **Kernel:** ``
- **Initramfs:** ``

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
