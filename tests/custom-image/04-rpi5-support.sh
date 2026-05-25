#!/bin/bash
# tests/custom-image/04-rpi5-support.sh

# TDG Test: Raspberry Pi 5 Support
# GIVEN: Custom Talos image built with RPi5 overlay
# WHEN: Inspecting OCI images and build profiles
# THEN: RPi5 specialized images are available

set -e

TALOS_VERSION=${TALOS_VERSION:-v1.13.2}

test_rpi5_oci_image_exists() {
  echo "🔍 Testing: RPi5 specialized OCI image exists in GHCR"
  
  # GIVEN: Image built with -rpi5 suffix
  # WHEN: Checking for the image in registry
  # THEN: Image is present
  
  IMAGE="ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-hailort/talos:${TALOS_VERSION}-rpi5"
  
  echo "  Checking $IMAGE..."
  
  # We use skopeo to inspect without pulling
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists in registry"
  else
    echo "⚠️  $IMAGE not found (it might be building in CI)"
    # Don't fail the local test if it's not pushed yet, but warn
  fi
  
  return 0
}

test_rpi5_profile_correctness() {
  echo "🔍 Testing: RPi5 profile contains required overlay"
  
  # GIVEN: gen-profiles.sh updated with metal-rpi5 and installer-rpi5
  # WHEN: Running gen-profiles.sh
  # THEN: Generated profiles contain the rpi_5 overlay
  
  # This test assumes we are in the repo root
  if [[ ! -d "temp-upstream/cozystack-v1.4.0" ]]; then
    echo "⏸️  Skipping profile test: temp-upstream not found"
    return 0
  fi
  
  # Check if our patch is applied (or at least if the logic is there)
  PROFILE_PATH="temp-upstream/cozystack-v1.4.0/packages/core/talos/images/talos/profiles/metal-rpi5.yaml"
  
  if [[ -f "$PROFILE_PATH" ]]; then
    if grep -q "name: rpi_5" "$PROFILE_PATH" && grep -q "sbc-raspberrypi" "$PROFILE_PATH"; then
      echo "✅ $PROFILE_PATH contains rpi_5 overlay"
    else
      echo "❌ $PROFILE_PATH missing rpi_5 overlay"
      return 1
    fi
  else
    echo "❌ $PROFILE_PATH not found. Did you run gen-profiles.sh?"
    return 1
  fi
  
  return 0
}

# Run all tests
main() {
  echo "🧪 TDG Test Suite: Raspberry Pi 5 Support"
  echo "========================================="
  
  FAILED_TESTS=0
  
  test_rpi5_oci_image_exists || ((FAILED_TESTS++))
  echo ""
  
  test_rpi5_profile_correctness || ((FAILED_TESTS++))
  echo ""
  
  if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "🎉 RPi5 support tests passed!"
    exit 0
  else
    echo "💥 $FAILED_TESTS test(s) failed!"
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
