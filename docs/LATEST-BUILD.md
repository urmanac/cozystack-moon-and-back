# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-17 05:08:20 UTC  
**Talos Version:** `v1.11.5`  
**CozyStack Commit:** ``  
**Build Target:** `assets`  
**Total Assets:** 6  

**Asset Digests:**
- **Kernel:** `sha256:2777e9bd8d98736ba632fa8cb34ff9f7815779e806d52a5379da872213bb1da8`
- **Initramfs:** `sha256:717729e430c8f6602c529fd0c3417cd49f0d5778f4baf9c0d45e6c69f71ec69b`

**Container Image:**
```bash
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable
```

**Complete Asset Extraction:**
```bash
# Extract complete ARM64 asset array with validation
mkdir -p /opt/cozystack-assets
docker run --rm -v /opt/cozystack-assets:/output \
  ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
  sh -c "cp -r /assets/* /output/"

# Verify checksums
cd /opt/cozystack-assets/talos/arm64
sha256sum -c checksums.sha256

# View build report
cat validation/build-report.txt
```

**For AWS Bastion Matchbox Setup:**
```bash
# Extract boot assets for matchbox
docker run --rm -v /opt/matchbox/assets:/output \
  ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
  sh -c "cp /assets/talos/arm64/boot/* /output/"
```
