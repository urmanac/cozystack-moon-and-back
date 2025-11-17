# Custom Talos Images for CozyStack Demo

## Overview

This document specifies the custom ARM64 Talos Linux images needed for the "Home Lab to the Moon and Back" demo. These images will be built using CozyStack's existing Makefile-based build system via **hephy-builder** pattern and stored in GHCR (GitHub Container Registry) for free.

**Based on proven approach**: [kingdonb/cozystack:merged-branches](https://github.com/kingdonb/cozystack/commits/merged-branches/) - 12 commits ahead with working Spin + Tailscale builds.

## Build Strategy: Proven CozyStack Fork Pattern

**Existing Pattern** (from your `merged-branches`):
```
kingdonb/cozystack fork → Manual builds → Docker Hub
├── cozystack-spin-only (Spin runtime only)  
├── cozystack-spin-tailscale (Spin + Tailscale)
└── Custom matchbox image (netboot configuration)
```

**New CI Pattern** (this project):
```
urmanac/cozystack-moon-and-back → GitHub Actions → GHCR
├── Reference kingdonb/cozystack commits c112ec63 → c21b1a86
├── Automate the proven manual build process
└── Add ARM64 architecture support
```

**Target Registry**: `ghcr.io/urmanac/talos-cozystack-demo`  
**Architecture**: ARM64 only (matches t4g instances and future Raspberry Pi CM3)  
**Versioning**: Mirror upstream CozyStack versions exactly (no custom versions)

## Proven Implementation Analysis

**From `kingdonb/cozystack:merged-branches`** - commit sequence c112ec63 → c21b1a86:

### Commit c112ec63: `publish (matchbox) to kingdonb on docker.io`
- **What**: Initial matchbox image publication to Docker Hub
- **Pattern**: Manual build process established
- **Registry**: `kingdonb/` namespace on Docker Hub

### Commit 24d566b: `hardcode spin + tailscale versions`  
- **What**: Pin specific extension versions for reproducibility
- **Extensions**: Spin runtime + Tailscale pinned to working versions
- **Approach**: Hardcoded rather than dynamic version fetching

### Commit 06a28cc: `hack/gen-profiles.sh`
- **What**: Modified profile generator for custom extensions
- **Changes**: Added Spin and Tailscale to extensions list
- **Pattern**: Patch CozyStack's existing build system

### Commit c581c59: `-tailscale` then e9c41ce: `Revert "-tailscale"`
- **What**: Testing different extension combinations
- **Variants**: spin-only vs. spin-tailscale builds
- **Strategy**: Multiple image variants for different use cases

### Commit ce8b1bb: `REGISTRY := kingdonb`
- **What**: Registry destination configuration
- **Pattern**: Simple variable override in Makefile
- **Target**: Docker Hub personal registry

### Commit 3d8e781: `build complete` 
- **What**: Successful manual build validation
- **Assets**: All custom Talos images built successfully
- **Quality**: Proven working state

### Commit 1c8e759: `matchbox.tag`
- **What**: Matchbox image tagging/versioning
- **Integration**: Matchbox configured for custom Talos images
- **Pattern**: Separate matchbox build after Talos assets

### Commit c21b1a86: `publish matchbox image`
- **What**: Final step - publish matchbox with custom configuration  
- **Complete**: End-to-end custom netboot infrastructure
- **Status**: Production-ready manual process

## Our Automation Strategy

**Convert proven manual process → GitHub Actions automation:**

1. **Clone kingdonb/cozystack** at working commit
2. **Apply ARM64 patches** on top of proven x86_64 changes
3. **Update registry target** from `kingdonb` → `ghcr.io/urmanac`
4. **Automate build sequence** following exact commit pattern
5. **Generate both variants**: spin-only and spin-tailscale
6. **Build custom matchbox** with ARM64 asset configuration
7. **Version mirroring** to match upstream CozyStack releases

## Hephy-Builder Integration

**Repository Pattern**:
```
urmanac/cozystack-moon-and-back
├── .github/workflows/build-talos-images.yml
├── patches/
│   ├── 01-arm64-architecture.patch
│   ├── 02-add-spin-extension.patch
│   └── 03-add-tailscale-extension.patch
└── scripts/
    └── build-cozystack-images.sh
```

**Build Process**:
1. **Clone**: `git clone https://github.com/cozystack/cozystack.git`
2. **Patch**: Apply patches for ARM64 + Spin + Tailscale
3. **Build Dependencies**: Ensure `docker`, `skopeo`, `jq`, `yq` available
4. **Generate Profiles**: Run patched `hack/gen-profiles.sh` for ARM64
5. **Build Images**: Run `make talos-metal talos-kernel talos-initramfs`
6. **Extract Assets**: Get kernel/initramfs for matchbox server
7. **Push**: Upload to GHCR with proper tags

**GitHub Actions Environment**:
- ✅ `runs-on: ubuntu-latest` has Docker + build tools
- ✅ QEMU available for ARM64 emulation via `docker/setup-qemu-action`
- ✅ Can run `make` commands directly (no kaniko needed)
- ✅ GHCR authentication via `GITHUB_TOKEN`

## Integration Points

### Matchbox Server Configuration
The bastion's matchbox server will serve these images:

```yaml
# /opt/matchbox/assets/talos/
kernel: /assets/talos/custom/vmlinuz-arm64
initramfs: /assets/talos/custom/initramfs-arm64.xz
```

**Image Pull Strategy**:
1. GitHub Actions builds → GHCR
2. Bastion pulls image on startup via Docker
3. Extract kernel/initramfs from OCI image to matchbox assets
4. Serve via HTTP to netbooting nodes

### Flux ExternalArtifact (Future)
If using Flux 2.7+ ExternalArtifact features:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: ExternalArtifact
metadata:
  name: talos-cozystack-custom
spec:
  url: oci://ghcr.io/urmanac/talos-cozystack-demo
  tag: demo-stable
  layer: 
    mediaType: application/vnd.oci.image.layer.v1.tar
    digest: sha256:...
```

## Test-Driven Validation

### Test 1: Image Builds Successfully
```bash
#!/bin/bash
# tests/custom-image/01-build-success.sh

test_github_actions_build_succeeds() {
  # GIVEN: GitHub Actions workflow triggered
  # WHEN: Building custom Talos image
  # THEN: Build completes without errors AND image pushed to GHCR
  
  # This will be validated via GitHub Actions status
  # Manual verification: check Actions tab for green checkmarks
  echo "Check: https://github.com/urmanac/cozystack-moon-and-back/actions"
  true
}

test_image_pullable_from_ghcr() {
  # GIVEN: Image built and pushed
  # WHEN: Pulling from GHCR
  # THEN: Pull succeeds without authentication (public repo)
  
  docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable
}
```

### Test 2: Extensions Present
```bash
#!/bin/bash
# tests/custom-image/02-extensions-present.sh

test_spin_runtime_available() {
  # GIVEN: Custom Talos image running
  # WHEN: Checking for Spin extension
  # THEN: Spin binary exists and RuntimeClass created
  
  # Run on actual node:
  # talosctl -n 10.20.13.x get runtimeclass spin
  echo "Manual validation required on running node"
}

test_tailscale_extension_available() {
  # GIVEN: Custom Talos image running  
  # WHEN: Checking for Tailscale extension
  # THEN: Tailscale service available
  
  # talosctl -n 10.20.13.x get services | grep tailscale
  echo "Manual validation required on running node"
}
```

### Test 3: Netboot Integration
```bash
#!/bin/bash
# tests/custom-image/03-netboot-integration.sh

test_matchbox_serves_custom_kernel() {
  # GIVEN: Bastion with custom image assets
  # WHEN: Matchbox serves boot files
  # THEN: Custom kernel/initramfs served successfully
  
  curl -s http://10.20.13.140:8080/assets/talos/custom/vmlinuz-arm64 > /dev/null
  curl -s http://10.20.13.140:8080/assets/talos/custom/initramfs-arm64.xz > /dev/null
}

test_node_boots_with_extensions() {
  # GIVEN: Node netboots custom image
  # WHEN: Talos starts up
  # THEN: Extensions are loaded and functional
  
  # This is end-to-end validation - requires actual AWS test
  echo "End-to-end test: deploy node, check extension availability"
}
```

## Build Workflow Structure

```
.github/workflows/build-talos-images.yml
├── Trigger: Push to main, PR to main, manual dispatch
├── Job: build-custom-talos-arm64
│   ├── Setup: checkout, Docker buildx, QEMU
│   ├── Login: GHCR with GITHUB_TOKEN
│   ├── Build: Custom Dockerfile with extensions
│   ├── Test: Basic smoke tests on image
│   ├── Push: Multiple tags to GHCR
│   └── Outputs: Image digest, tags pushed
└── Job: update-matchbox-assets (future)
    ├── Extract: kernel/initramfs from OCI image  
    ├── Upload: To S3 or artifact storage
    └── Notify: Update bastion configuration
```

## Next Actions

1. **Identify Spin Extension Source**: 
   - Check Talos documentation for official Spin extension
   - If none exists, plan custom build process
   - Research SpinKube requirements for runtime integration

2. **Identify Tailscale Extension Source**:
   - Check Talos extensions catalog
   - Verify ARM64 compatibility
   - Plan authentication strategy (auth keys, etc.)

3. **Create Initial Dockerfile**:
   - Base FROM ghcr.io/siderolabs/talos:v1.9.0
   - Add extension installation steps
   - Optimize for GitHub Actions build time

4. **Setup GitHub Actions Workflow**:
   - Configure GHCR authentication
   - Test ARM64 builds via QEMU
   - Add build caching for faster iterations

## Questions for AWS-Capable Claude Agent

When ready to hand off infrastructure planning:

1. **Bastion Image Extraction**: How should bastion pull OCI images and extract kernel/initramfs for matchbox?
2. **AWS Cost Implications**: Any costs for GHCR pulls from EC2 instances?
3. **Networking**: How will bastion pull images during startup? (NAT gateway egress)
4. **Security**: IAM roles needed for ECR/GHCR access, or just public pulls?

## Success Criteria

- [ ] GitHub Actions builds custom ARM64 Talos images successfully
- [ ] Images available via `docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable`
- [ ] Bastion can extract and serve kernel/initramfs from OCI images
- [ ] Nodes boot custom images and extensions are functional
- [ ] Zero additional cost beyond base AWS infrastructure
- [ ] Process documented for community replication

---

*Next Document: GitHub Actions workflow configuration*  
*Status: Ready for AWS infrastructure planning handoff*