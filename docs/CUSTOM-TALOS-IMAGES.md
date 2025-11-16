# Custom Talos Images for CozyStack Demo

## Overview

This document specifies the custom ARM64 Talos Linux images needed for the "Home Lab to the Moon and Back" demo. These images will be built using CozyStack's existing Makefile-based build system via **hephy-builder** (formerly kaniko-builder) pattern and stored in GHCR (GitHub Container Registry) for free.

## Build Strategy: Hephy-Builder + CozyStack Integration

**Approach**: Use CozyStack's existing `talos-imager` build system, not custom Dockerfiles
**Pattern**: Clone `cozystack/cozystack` → Apply ARM64 + Spin/Tailscale patches → Run Make targets
**Base**: CozyStack's profiles system with custom extensions
**Target Registry**: `ghcr.io/urmanac/talos-cozystack-demo`
**Architecture**: ARM64 only (matches t4g instances and future Raspberry Pi CM3)

## CozyStack Build System Analysis

**Current State** (from `cozystack/cozystack` repo):
- Uses `ghcr.io/siderolabs/imager:${TALOS_VERSION}` for builds
- Profile generator: `hack/gen-profiles.sh` creates YAML configs
- Make targets: `talos-metal`, `talos-kernel`, `talos-initramfs`, etc.
- **Problem**: Only AMD64 architecture supported
- **Problem**: No Spin or Tailscale extensions included

**Our Patches Required**:
1. **ARM64 Architecture**: Modify profile generator to support `arch: arm64`
2. **Spin Runtime Extension**: Add SpinKube extension to systemExtensions list
3. **Tailscale Extension**: Add Tailscale extension to systemExtensions list
4. **Build Pipeline**: Adapt Make targets to work in GitHub Actions environment

## Required Extensions

### 1. Spin Runtime Extension
- **Purpose**: Enable SpinKube workloads (WebAssembly on Kubernetes)
- **Source**: Need to identify/build Spin extension for Talos
- **Integration**: Add to `systemExtensions` in profile YAML
- **Validation**: `spin --version` should work on nodes + `spin` RuntimeClass created

### 2. Tailscale Extension  
- **Purpose**: Secure networking overlay for home lab integration
- **Source**: Check if official Talos Tailscale extension exists
- **Integration**: Add to `systemExtensions` in profile YAML  
- **Validation**: `tailscale status` should work on nodes

## Image Tags Strategy

```
ghcr.io/urmanac/talos-cozystack-demo:v1.9.0-spin-tailscale-latest
ghcr.io/urmanac/talos-cozystack-demo:v1.9.0-spin-tailscale-20251116
ghcr.io/urmanac/talos-cozystack-demo:demo-stable
```

- **Latest**: Rolling tag for development
- **Dated**: Immutable builds for reproducibility  
- **demo-stable**: Tag used in actual demo (never moves)

## Build Requirements

### GitHub Actions Free Tier Constraints
- ✅ ARM64 builds supported via `runs-on: ubuntu-latest` with QEMU
- ✅ GHCR pushes free for public repos
- ✅ Build time should be <30 minutes (generous free tier limits)
- ❌ No cost for storage (public images)

### Build Dependencies
- Docker buildx for multi-arch builds
- QEMU for ARM64 emulation
- GitHub token with `packages:write` permission
- Reference to existing `kingdon-ci/kaniko-builder` patterns

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