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

**Issue:** Homogeneous clusters don't need both extensions, causing unnecessary resource usage.

### 🎯 Required Tasks

#### 1. **Implement Dual Image Strategy**
Create separate build variants:
- **spin-only**: `EXTENSIONS="drbd zfs spin"` 
- **tailscale+spin**: `EXTENSIONS="drbd zfs spin tailscale"`

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
- ✅ Two distinct ARM64 image variants published
- ✅ Production-ready images for homogeneous clusters
- ✅ Docs-only changes don't trigger rebuilds

Repository: `urmanac/cozystack-moon-and-back` on `main` branch  
Container Registry: `ghcr.io/urmanac/talos-cozystack-demo`
