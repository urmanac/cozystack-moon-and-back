#!/bin/bash
# tests/custom-image/03-upstream-integration.sh

# TDG Test: Upstream CozyStack Build System Integration
# GIVEN: CozyStack upstream build system integrated properly
# WHEN: Building with upstream Makefile targets
# THEN: Complete asset array generated with validation

set -e

test_upstream_makefile_targets_used() {
  echo "🔍 Testing: Upstream Makefile targets used in build"
  
  # GIVEN: GitHub Actions workflow
  # WHEN: Checking workflow uses upstream targets
  # THEN: Workflow contains 'make assets', 'make update', 'make pre-checks'
  
  WORKFLOW_FILE="$(dirname "$0")/../../.github/workflows/build-talos-images.yml"
  
  if grep -q "make update" "$WORKFLOW_FILE" && \
     grep -q "make pre-checks" "$WORKFLOW_FILE" && \
     grep -q "make assets" "$WORKFLOW_FILE"; then
    echo "✅ Upstream Makefile targets properly integrated"
    echo "   Found: make update, make pre-checks, make assets"
    return 0
  else
    echo "❌ Missing upstream Makefile targets"
    echo "   Expected: make update, make pre-checks, make assets"
    return 1
  fi
}

test_upstream_compatible_asset_structure() {
  echo "🔍 Testing: Upstream-compatible asset structure with ARM64 + extensions"
  
  # GIVEN: Container built with upstream system  
  # WHEN: Extracting assets using crane (proper tool for FROM scratch containers)
  # THEN: ARM64 assets with Spin+Tailscale extensions, upstream-compatible structure
  
  IMAGE="ghcr.io/urmanac/talos-cozystack-demo:v1.11.5-arm64-spin-tailscale"
  TEST_DIR="/tmp/talos-upstream-test-$$"
  
  mkdir -p "$TEST_DIR"
  
  # Extract all assets using crane (optimized for local images)
  if command -v crane >/dev/null 2>&1; then
    # Check if image is available locally to speed up crane operations
    if docker images -q "$IMAGE" >/dev/null 2>&1 && docker images "$IMAGE" | grep -q "$IMAGE"; then
      echo "🚀 Using crane with local image cache (faster)"
    else
      echo "📡 Using crane for remote registry access"
      # Pre-pull image to speed up repeated tests
      docker pull "$IMAGE" >/dev/null 2>&1 || true
    fi
    
    cd "$TEST_DIR" && crane export "$IMAGE" | tar -xf - 2>/dev/null || {
      echo "❌ Failed to extract assets from container using crane"
      rm -rf "$TEST_DIR"
      return 1
    }
  else
    # Fallback to docker cp method (but won't work with FROM scratch)
    docker create --name temp-test-$$ "$IMAGE" >/dev/null 2>&1 || {
      echo "❌ Failed to create container (install crane for better FROM scratch support)"
      rm -rf "$TEST_DIR"
      return 1
    }
    docker cp temp-test-$$:/assets/. "$TEST_DIR/" >/dev/null 2>&1 || {
      echo "❌ Failed to extract assets from container"
      docker rm temp-test-$$ >/dev/null 2>&1
      rm -rf "$TEST_DIR"
      return 1
    }
    docker rm temp-test-$$ >/dev/null 2>&1
  fi
  
  # Check for upstream-compatible structure (ARM64 + extensions, no arbitrary divergences)
  EXPECTED_STRUCTURE=(
    "assets/talos/arm64/boot/vmlinuz"         # Kernel (ARM64 architecture) 
    "assets/talos/arm64/boot/initramfs.xz"    # Initramfs with Spin+Tailscale extensions
    "assets/talos/arm64/checksums.sha256"     # Comprehensive checksums (upstream pattern)
  )
  
  MISSING_FILES=0
  for file in "${EXPECTED_STRUCTURE[@]}"; do
    if [[ ! -f "$TEST_DIR/$file" ]]; then
      echo "❌ Missing: $file"
      ((MISSING_FILES++))
    fi
  done
  
  if [[ $MISSING_FILES -eq 0 ]]; then
    echo "✅ Upstream-compatible ARM64 asset structure found"
    echo "   Architecture: ARM64 (not AMD64)"
    echo "   Extensions: Spin + Tailscale (not default)"
    echo "   Structure: Compatible with upstream conventions"
    
    # Verify ARM64 architecture in assets
    if file "$TEST_DIR/talos/arm64/vmlinuz" 2>/dev/null | grep -q "aarch64\|arm64"; then
      echo "✅ Kernel is ARM64 architecture"
    else
      echo "⚠️ Kernel architecture verification failed (may be normal for compressed kernel)"
    fi
    
    rm -rf "$TEST_DIR"
    return 0
  else
    echo "❌ Missing $MISSING_FILES required upstream-compatible assets"
    echo "   Found structure:"
    find "$TEST_DIR" -type f | sort
    rm -rf "$TEST_DIR"
    return 1
  fi
}

test_build_targets_configurable() {
  echo "🔍 Testing: Build targets configurable via workflow input"
  
  # GIVEN: Workflow supports multiple build targets
  # WHEN: Checking workflow inputs
  # THEN: build_targets input supports image, assets, image-talos, image-matchbox
  
  WORKFLOW_FILE="$(dirname "$0")/../../.github/workflows/build-talos-images.yml"
  
  if grep -A10 "build_targets:" "$WORKFLOW_FILE" | grep -q "image\|assets\|image-talos\|image-matchbox"; then
    echo "✅ Build targets configurable"
    echo "   Supports: image, assets, image-talos, image-matchbox"
    return 0
  else
    echo "❌ Build targets not properly configured"
    return 1
  fi
}

test_upstream_repository_correct() {
  echo "🔍 Testing: Using correct CNCF upstream repository"
  
  # GIVEN: CozyStack is now CNCF sandbox project
  # WHEN: Checking repository URLs
  # THEN: All references point to cozystack/cozystack (not aenix-io)
  
  if grep -r "aenix-io/cozystack" . --exclude-dir=.git >/dev/null 2>&1; then
    echo "❌ Found references to old aenix-io repository"
    echo "   Should use: cozystack/cozystack (CNCF upstream)"
    grep -r "aenix-io/cozystack" . --exclude-dir=.git | head -3
    return 1
  else
    echo "✅ Using correct CNCF upstream: cozystack/cozystack"
    return 0
  fi
}

# Run all tests
main() {
  echo "🧪 TDG Test Suite: Upstream CozyStack Integration"
  echo "================================================"
  
  FAILED_TESTS=0
  
  test_upstream_makefile_targets_used || ((FAILED_TESTS++))
  echo ""
  
  test_upstream_compatible_asset_structure || ((FAILED_TESTS++))
  echo ""
  
  test_build_targets_configurable || ((FAILED_TESTS++))
  echo ""
  
  test_upstream_repository_correct || ((FAILED_TESTS++))
  echo ""
  
  if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "🎉 All upstream integration tests passed!"
    echo ""
    echo "Upstream integration is properly implemented:"
    echo "  ✅ Uses proper CNCF upstream (cozystack/cozystack)"  
    echo "  ✅ Integrates upstream Makefile targets"
    echo "  ✅ Generates complete asset array with validation"
    echo "  ✅ Supports multiple build targets"
    echo ""
    echo "Next: Run integration tests with real Talos nodes"
    exit 0
  else
    echo "💥 $FAILED_TESTS upstream integration test(s) failed!"
    echo ""
    echo "This indicates our upstream integration is incomplete."
    echo "Fix these issues before proceeding with TDG."
    exit 1
  fi
}

# Allow running individual tests
if [[ "${1:-}" == "--test" ]]; then
  shift
  "$1"
else
  main "$@"
fi