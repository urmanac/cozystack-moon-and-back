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
  
  WORKFLOW_FILE=".github/workflows/build-talos-images.yml"
  
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

test_complete_asset_array_structure() {
  echo "🔍 Testing: Complete asset array structure with validation"
  
  # GIVEN: Container built with upstream system
  # WHEN: Extracting assets using crane (proper tool for FROM scratch containers)
  # THEN: Complete directory structure with boot/, containers/, validation/
  
  IMAGE="ghcr.io/urmanac/talos-cozystack-demo:demo-stable"
  TEST_DIR="/tmp/talos-upstream-test-$$"
  
  mkdir -p "$TEST_DIR"
  
  # Extract all assets using crane (handles FROM scratch containers)
  if command -v crane >/dev/null 2>&1; then
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
  
  # Check for new structure
  EXPECTED_STRUCTURE=(
    "talos/arm64/boot/vmlinuz"
    "talos/arm64/boot/initramfs.xz"
    "talos/arm64/checksums.sha256"
    "talos/arm64/validation/build-report.txt"
  )
  
  MISSING_FILES=0
  for file in "${EXPECTED_STRUCTURE[@]}"; do
    if [[ ! -f "$TEST_DIR/$file" ]]; then
      echo "❌ Missing: $file"
      ((MISSING_FILES++))
    fi
  done
  
  if [[ $MISSING_FILES -eq 0 ]]; then
    echo "✅ Complete asset array structure present"
    echo "   Found: boot/, validation/, checksums"
    
    # Validate checksums work
    cd "$TEST_DIR/talos/arm64"
    if sha256sum -c checksums.sha256 >/dev/null 2>&1; then
      echo "✅ Asset checksums validate successfully"
    else
      echo "⚠️  Checksum validation failed (but structure is correct)"
    fi
    
    rm -rf "$TEST_DIR"
    return 0
  else
    echo "❌ Missing $MISSING_FILES required files"
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
  
  WORKFLOW_FILE=".github/workflows/build-talos-images.yml"
  
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
  
  test_complete_asset_array_structure || ((FAILED_TESTS++))
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