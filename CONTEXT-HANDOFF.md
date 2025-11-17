# Context Handoff Instructions

## 🎯 Project Overview
**CozyStack Moon and Back** - ARM64 Talos images with Spin runtime + Tailscale networking for CozySummit Virtual 2025 demo.

**Current Status:** Successfully built working ARM64 Talos images, complete documentation with GitHub Pages, now integrating upstream CozyStack build system to replace custom approach.

**Current Branch:** `upstream-build-system`
**Repository:** https://github.com/urmanac/cozystack-moon-and-back
**GitHub Pages:** https://urmanac.github.io/cozystack-moon-and-back/

## 🚀 Major Accomplishments
✅ **ARM64 Talos Images:** Working builds with Spin runtime + Tailscale networking
✅ **Documentation System:** Complete ADR system with professional GitHub Pages site  
✅ **CI/CD Pipeline:** Automated builds publishing to GitHub Container Registry
✅ **GitHub Pages:** Beautiful Jekyll-powered documentation site deployed successfully

## 🔄 Current Work (In Progress)
**Primary Task:** Integrating upstream CozyStack Makefile targets to replace our custom build approach

**What We're Doing:**
- Replacing custom build steps with upstream CozyStack Makefile targets: `make image`, `make assets`, `make talos-kernel`, `make talos-initramfs`
- Maintaining ARM64 + Spin + Tailscale patches while using proper upstream build system
- Following CozyStack upstream patterns from: https://github.com/cozystack/cozystack/blob/main/packages/core/installer/Makefile

**Current Issue:** Was in process of completely rewriting `.github/workflows/build-talos-images.yml` to use upstream build system but hit context limits.

## 📋 Active Todo List
```markdown
- [🔄] Integrate upstream CozyStack build system
  - Replace our custom Talos build approach with upstream CozyStack Makefile targets (make image, make assets, make talos-kernel, make talos-initramfs)
- [ ] Clean up unsourced claims in docs  
  - Remove unsourced data points from documentation, especially the 76°F claim and other unqualified numbers
- [ ] Add automated dependency updates
  - Add automated workflow to update CozyStack dependencies and create PRs using gh cli, following Flux CD pattern
- [ ] Add proper documentation citations
  - Improve documentation with proper citations and source references  
- [ ] Build complete upstream asset array
  - Build matchbox and talos installer images using upstream targets, with checksums and validation
```

## 🔧 Technical Architecture

### Core Components
1. **ARM64 Talos Images:** Custom Talos Linux for ARM64 with Spin WebAssembly runtime + Tailscale networking
2. **CozyStack Integration:** Kubernetes platform running on our custom Talos
3. **GitHub Container Registry:** Automated publishing of built images
4. **GitHub Pages:** Documentation and presentation site

### Key Files
- `.github/workflows/build-talos-images.yml` - **Currently being refactored** to use upstream build system
- `patches/01-arm64-spin-tailscale.patch` - Clean Git-generated patch for ARM64 conversion
- `docs/ADRs/` - Complete Architecture Decision Records system
- `_config.yml`, `index.md` - GitHub Pages Jekyll configuration
- `LATEST-BUILD.md` - Auto-updated build status documentation

### Build Process (Target State)
```bash
# Clone upstream CozyStack
git clone https://github.com/cozystack/cozystack.git cozystack-upstream

# Apply our ARM64 + Spin + Tailscale patches  
git apply patches/01-arm64-spin-tailscale.patch

# Use upstream Makefile targets
cd cozystack-upstream/packages/core/installer
make image        # Full build (pre-checks + matchbox + cozystack + talos)
make assets       # Just Talos assets (kernel + initramfs) 
make talos-kernel # Just kernel
make talos-initramfs # Just initramfs
```

## 📁 File Structure
```
cozystack-moon-and-back/
├── .github/workflows/
│   ├── build-talos-images.yml     # 🔄 BEING REFACTORED - upstream integration
│   └── pages.yml                  # ✅ GitHub Pages deployment
├── docs/
│   ├── ADRs/                      # ✅ Complete ADR system
│   │   ├── ADR-001-arm64-architecture.md
│   │   ├── ADR-002-tdg-methodology.md  
│   │   ├── ADR-003-patch-generation.md
│   │   └── README.md
│   ├── LATEST-BUILD.md            # ✅ Auto-updated build status
│   ├── REPO-OVERVIEW.md           # ✅ Complete overview
│   └── TDG-PLAN.md                # ✅ Technical delivery guide
├── patches/
│   └── 01-arm64-spin-tailscale.patch # ✅ Clean Git patch for ARM64 conversion
├── _config.yml                    # ✅ Jekyll configuration
├── index.md                       # ✅ GitHub Pages homepage
└── README.md                      # ✅ Project overview
```

## 🔧 Upstream Integration Details

### CozyStack Makefile Targets (Source: https://github.com/cozystack/cozystack/blob/main/packages/core/installer/Makefile)
- `make pre-checks` - Verify build dependencies
- `make update` - Run gen-profiles.sh to generate Talos profiles  
- `make image` - Full build (pre-checks + image-matchbox + image-cozystack + image-talos)
- `make assets` - Build Talos assets (talos-iso + talos-nocloud + talos-metal + talos-kernel + talos-initramfs)
- `make image-talos` - Build Talos installer image
- `make image-matchbox` - Build matchbox image
- `make talos-kernel` - Build ARM64 kernel with extensions
- `make talos-initramfs` - Build ARM64 initramfs with extensions

### Required Dependencies (from upstream)
```bash
# Core tools
sudo apt-get install -y skopeo jq

# Container registry tool  
curl -L https://github.com/google/go-containerregistry/releases/latest/download/go-containerregistry_Linux_x86_64.tar.gz | sudo tar xz -C /usr/local/bin crane

# YAML processor (mikefarah/yq)
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq

# Multi-platform Docker builds
docker buildx create --use --name multi-platform
```

## 🎨 GitHub Pages Setup
**Status:** ✅ Fully deployed and working
**URL:** https://urmanac.github.io/cozystack-moon-and-back/
**Theme:** Clean, responsive Jekyll theme with navigation

### Jekyll Configuration (_config.yml)
```yaml
title: "CozyStack Moon and Back"
description: "ARM64 Talos images for CozySummit Virtual 2025"
theme: minima
plugins:
  - jekyll-feed
  - jekyll-sitemap
markdown: kramdown
highlighter: rouge
```

### Navigation Structure
- Homepage: Project overview with demo links
- ADR System: Professional architecture decisions
- Latest Build: Auto-updated build status
- Repository: GitHub source code

## 🐛 Recent Issue Context

**Problem:** Was refactoring `.github/workflows/build-talos-images.yml` to use upstream CozyStack Makefile targets but hit context limits.

**What Was Attempted:**
1. Used `grep_search` to find all references to old job name `build-cozystack-talos-arm64`
2. Multiple `replace_string_in_file` attempts failed due to text mismatches
3. Tried to completely rewrite workflow file with upstream integration

**Current File State:** 
- File still contains old custom build approach
- Job name: `build-cozystack-talos-arm64` (needs to be `build-cozystack-upstream`)
- Build steps: Still using custom approach (needs upstream Makefile targets)

**Next Steps:**
1. Examine current workflow file content 
2. Replace entire workflow with upstream integration approach
3. Ensure ARM64 + Spin + Tailscale patches are still applied
4. Test build works with upstream targets
5. Update job dependencies and output references

## 📋 Workflow Refactoring Requirements

### Current Workflow Structure (to be replaced)
```yaml
jobs:
  build-cozystack-talos-arm64:  # OLD NAME
    steps:
      - name: Clone and setup CozyStack (upstream main)
      - name: Apply ARM64 conversion patches  
      - name: Build ARM64 Talos images with Spin+Tailscale  # CUSTOM APPROACH
```

### Target Workflow Structure (what we want)
```yaml  
jobs:
  build-cozystack-upstream:     # NEW NAME
    steps:
      - name: Install upstream build dependencies
      - name: Clone upstream CozyStack  
      - name: Apply ARM64 conversion patches
      - name: Update upstream dependencies  # make update
      - name: Build with upstream Makefile targets  # make image/assets/etc
```

### Workflow Inputs (keep these)
```yaml
workflow_dispatch:
  inputs:
    cozystack_commit:
      description: 'CozyStack upstream commit (for reproducible builds)'
      default: 'HEAD'
    build_targets:
      type: choice
      options:
        - 'image'           # make image  
        - 'assets'          # make assets
        - 'image-talos'     # make image-talos
        - 'image-matchbox'  # make image-matchbox
```

## 🔗 Important URLs & References
- **Upstream CozyStack:** https://github.com/cozystack/cozystack
- **Upstream Makefile:** https://github.com/cozystack/cozystack/blob/main/packages/core/installer/Makefile
- **Our Repository:** https://github.com/urmanac/cozystack-moon-and-back
- **GitHub Pages:** https://urmanac.github.io/cozystack-moon-and-back/
- **Container Registry:** ghcr.io/urmanac/talos-cozystack-demo

## 🚨 Critical Context Notes
1. **Branch:** Currently on `upstream-build-system` branch - this is where integration work happens
2. **Patches:** Our `patches/01-arm64-spin-tailscale.patch` is the key to ARM64 conversion - must be preserved
3. **Build Output:** Container images published to `ghcr.io/urmanac/talos-cozystack-demo` with tags like `demo-stable`, `latest`
4. **Documentation:** Remove any unsourced claims (especially 76°F temperature claim) and add proper citations
5. **Dependencies:** Follow Flux CD pattern for automated dependency updates via PRs

## 🎯 Immediate Next Actions
1. **Complete workflow refactoring** - Replace custom build with upstream Makefile targets
2. **Test upstream integration** - Ensure ARM64 + Spin + Tailscale still works 
3. **Documentation cleanup** - Remove unsourced claims, add citations
4. **Automated updates** - Add dependency update workflow with gh cli PR creation

## 💡 Success Criteria
- ✅ ARM64 Talos images still build successfully with Spin + Tailscale
- ✅ Using proper upstream CozyStack Makefile targets instead of custom approach  
- ✅ Documentation is accurate with proper citations
- ✅ Automated dependency updates via PR workflow
- ✅ Clean, maintainable codebase following upstream patterns

---
**Context Transfer Complete** - Next agent should continue upstream build system integration starting with workflow file refactoring.