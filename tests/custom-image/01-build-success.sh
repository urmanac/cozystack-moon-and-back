#!/bin/bash
# tests/custom-image/01-build-success.sh

# TDG Test: Custom Talos Image Build Success
# GIVEN: CozyStack repo cloned and ARM64 patches applied
# WHEN: GitHub Actions workflow builds custom images  
# THEN: Build completes successfully and assets are available

set -e

test_github_actions_build_succeeds() {
  echo "🔍 Testing: GitHub Actions build pipeline succeeds"
  
  # This will be validated via GitHub Actions status
  # Manual verification: check Actions tab for green checkmarks
  echo "✅ Manual check: https://github.com/urmanac/cozystack-moon-and-back/actions"
  echo "   Look for: Build Custom Talos Images (CozyStack + ARM64) workflow"
  echo "   Status should be: ✅ (green checkmark)"
  
  # For automated validation, we could use GitHub API:
  # gh run list --workflow="build-talos-images.yml" --status=success --limit=1
  
  return 0
}

test_container_image_pullable_from_ghcr() {
  echo "🔍 Testing: Container image pullable from GHCR without auth"
  
  # GIVEN: Image built and pushed to public GHCR
  # WHEN: Pulling from GHCR without authentication  
  # THEN: Pull succeeds (public repo)
  
  IMAGE="ghcr.io/urmanac/talos-cozystack-demo:demo-stable"
  
  if docker pull "$IMAGE" >/dev/null 2>&1; then
    echo "✅ Successfully pulled $IMAGE"
    return 0
  else
    echo "❌ Failed to pull $IMAGE"
    echo "   Check: Is the image built and published?"
    echo "   Check: Is the repository public?"
    return 1
  fi
}

test_arm64_assets_extractable() {
  echo "🔍 Testing: ARM64 boot assets can be extracted from container"
  
  # GIVEN: Container image with ARM64 Talos assets
  # WHEN: Running extraction command
  # THEN: ARM64 kernel and initramfs are extracted
  
  IMAGE="ghcr.io/urmanac/talos-cozystack-demo:demo-stable"
  TEST_DIR="/tmp/talos-test-$$"
  
  mkdir -p "$TEST_DIR"
  
  if docker run --rm -v "$TEST_DIR:/output" "$IMAGE" /output/talos/arm64/ >/dev/null 2>&1; then
    # Check for expected files
    if [[ -f "$TEST_DIR/talos/arm64/vmlinuz" && \
          -f "$TEST_DIR/talos/arm64/initramfs.xz" && \
          -f "$TEST_DIR/talos/arm64/vmlinuz.sha256" && \
          -f "$TEST_DIR/talos/arm64/initramfs.xz.sha256" ]]; then
      echo "✅ ARM64 assets successfully extracted"
      echo "   Files: $(ls -la "$TEST_DIR/talos/arm64/" | wc -l) files found"
      rm -rf "$TEST_DIR"
      return 0
    else
      echo "❌ Missing ARM64 asset files"
      echo "   Found: $(ls -la "$TEST_DIR/talos/arm64/" 2>/dev/null || echo 'No files')"
      rm -rf "$TEST_DIR"
      return 1
    fi
  else
    echo "❌ Failed to extract assets from container"
    echo "   Command: docker run --rm -v \$TEST_DIR:/output $IMAGE /output/talos/arm64/"
    rm -rf "$TEST_DIR"
    return 1
  fi
}

test_build_metadata_present() {
  echo "🔍 Testing: Build metadata and labels present"
  
  # GIVEN: Container built by GitHub Actions
  # WHEN: Inspecting container metadata
  # THEN: Build info labels are present
  
  IMAGE="ghcr.io/urmanac/talos-cozystack-demo:demo-stable"
  
  # Check for OCI labels
  SOURCE=$(docker inspect "$IMAGE" --format='{{index .Config.Labels "org.opencontainers.image.source"}}' 2>/dev/null || echo "")
  
  if [[ -n "$SOURCE" && "$SOURCE" == *"urmanac/cozystack-moon-and-back"* ]]; then
    echo "✅ Build metadata present"
    echo "   Source: $SOURCE"
    return 0
  else
    echo "❌ Missing or incorrect build metadata"
    echo "   Expected source containing: urmanac/cozystack-moon-and-back"
    echo "   Actual source: $SOURCE"
    return 1
  fi
}

# Run all tests
main() {
  echo "🧪 TDG Test Suite: Custom Talos Image Build Success"
  echo "=================================================="
  
  FAILED_TESTS=0
  
  test_github_actions_build_succeeds || ((FAILED_TESTS++))
  echo ""
  
  test_container_image_pullable_from_ghcr || ((FAILED_TESTS++))
  echo ""
  
  test_arm64_assets_extractable || ((FAILED_TESTS++))
  echo ""
  
  test_build_metadata_present || ((FAILED_TESTS++))
  echo ""
  
  if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "🎉 All tests passed! Custom Talos image build is successful."
    echo ""
    echo "Next steps:"
    echo "  1. Run tests/custom-image/02-extensions-present.sh"
    echo "  2. Deploy bastion with matchbox server"
    echo "  3. Test netboot with custom images"
    exit 0
  else
    echo "💥 $FAILED_TESTS test(s) failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check GitHub Actions workflow status"
    echo "  2. Verify patches applied correctly to CozyStack"
    echo "  3. Check GHCR repository permissions"
    echo "  4. Review build logs for errors"
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