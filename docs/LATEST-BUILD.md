# Latest CozyStack ARM64 Talos Build

**Built:** 2025-11-17 02:56:23 UTC  
**Talos Version:** `v1.11.5`  
**CozyStack Commit:** ``  

**Asset Digests:**
- **Kernel:** `sha256:2777e9bd8d98736ba632fa8cb34ff9f7815779e806d52a5379da872213bb1da8`
- **Initramfs:** `sha256:bceeae65cfde54c2b452cd5be451e0000ca4a2d535ea3f3ea8a0b962e29c1eeb`

**Container Image:**
```bash
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable
```

**For AWS Bastion Matchbox Setup:**
```bash
# Extract boot assets
docker run --rm -v /opt/matchbox/assets:/output \
  ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
  /output/talos/arm64/
```
