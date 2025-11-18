## 🎯 Focused Task: Complete CozyStack ARM64 Dual Image Strategy

### Current Status
✅ **Working ARM64 Talos images** with upstream CozyStack integration  
✅ **Single image** with both Spin + Tailscale extensions  
❌ **Missing dual variants** needed for production clusters

### 🚨 Problem
Current patch applies both extensions to all images:
```diff
-EXTENSIONS="drbd zfs"
+EXTENSIONS="drbd zfs spin tailscale"
```

**Issue:** Kubernetes nodes only reach "Ready" state when ALL configured extensions are active. With tailscale on every node, multiple subnet routers conflict → cluster formation fails.

### 🎯 Required Tasks

#### 1. **Implement Dual Image Strategy**
Create separate build variants for different node roles:
- **compute nodes**: `EXTENSIONS="drbd zfs spin"` (majority of cluster)
- **gateway node**: `EXTENSIONS="drbd zfs spin tailscale"` (one per cluster)

**Implementation:** Modify workflow to build both variants with different patches/configs.

#### 2. **Optimize CI for Docs-Only Changes** 
Add path filtering to skip builds when only docs change:
```yaml
paths-ignore:
  - 'docs/**'
  - '*.md'
  - '_config.yml'
```

### 📁 Key Files
- build-talos-images.yml - Main CI workflow
- 01-arm64-spin-tailscale.patch - Current unified patch
- Need: Additional patches or workflow matrix for dual variants

### 💡 Success Criteria
- ✅ Two distinct ARM64 image variants published (compute vs gateway roles)
- ✅ Compute nodes (spin-only) can form cluster and reach Ready state
- ✅ Gateway node (spin+tailscale) provides subnet routing without conflicts
- ✅ Docs-only changes don't trigger rebuilds

Repository: `urmanac/cozystack-moon-and-back` on `main` branch  
Container Registry: `ghcr.io/urmanac/talos-cozystack-demo`
