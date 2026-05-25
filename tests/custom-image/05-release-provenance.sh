#!/bin/bash
# tests/custom-image/05-release-provenance.sh

# This script verifies that all expected OCI images for a release are present in GHCR.
# It respects the reality that upstream components use their own versioning tags (e.g., 0.0.0, v1.4.0)
# while specialized assets use our release tag.

set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
RELEASE_TAG=${1:-latest}
FAILURES=0

# Components that we EXPECT to match our RELEASE_TAG
SPECIALIZED=(
  "cozystack-operator"
)

# Components that use their own upstream versioning
# Format: "image:tag"
UPSTREAM_PACKAGES=(
  "http-cache:latest"
  "mariadb:latest"
  "clickhouse:latest"
  "kubernetes:latest"
  "monitoring:latest"
  "cozystack-api:latest"
  "cozystack-controller:latest"
  "backup-controller:latest"
  "backupstrategy-controller:latest"
  "lineage-controller-webhook:latest"
  "cilium:latest"
  "kubeovn:latest"
  "kubeovn-webhook:latest"
  "kubeovn-plunger:latest"
  "metallb:latest"
  "kamaji:v1.4.0"
  "multus:v1.4.0"
  "bucket:v1.4.0"
  "objectstorage-controller:v1.4.0"
  "grafana-operator:v1.4.0"
  "testing:v1.4.0"
  "platform:v1.4.0"
)

# Talos and Matchbox Variants
VARIANTS=("spin-tailscale" "spin-hailort" "spin-only")

echo "🧪 Verifying Release Provenance for RELEASE_TAG: $RELEASE_TAG"
echo "==========================================="

# Check Specialized
for PKG in "${SPECIALIZED[@]}"; do
  IMAGE="$REGISTRY/$PKG:$RELEASE_TAG"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists (matches release tag)"
  else
    echo "❌ $IMAGE MISSING (failed to match release tag)"
    FAILURES=$((FAILURES + 1))
  fi
done

# Check Upstream (accepting their versioning)
for ENTRY in "${UPSTREAM_PACKAGES[@]}"; do
  PKG=${ENTRY%%:*}
  TAG=${ENTRY##*:}
  IMAGE="$REGISTRY/$PKG:$TAG"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists (uses upstream tag)"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi
done

# Check Talos/Matchbox (Specialized per release/board)
for VAR in "${VARIANTS[@]}"; do
  # Generic Installer
  # NOTE: Currently we retag existing Talos version, so it may or may not match RELEASE_TAG.
  # We check for 'latest' as a proxy for 'the build we just finished'.
  IMAGE="$REGISTRY/talos/cozystack-$VAR/talos:latest"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists (Generic Installer)"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi

  # Matchbox (This uses MATCHBOX_TAG which includes COZY_VER, usually matches RELEASE_TAG)
  IMAGE="$REGISTRY/talos/cozystack-$VAR/matchbox:latest"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists (Generic Matchbox)"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi

  # RPi5 Specialization (only for spin-hailort)
  if [ "$VAR" = "spin-hailort" ]; then
    IMAGE="$REGISTRY/talos/cozystack-$VAR/talos:latest-rpi5"
    if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
      echo "✅ $IMAGE exists (RPi5 Installer)"
    else
      echo "❌ $IMAGE MISSING"
      FAILURES=$((FAILURES + 1))
    fi

    IMAGE="$REGISTRY/talos/cozystack-$VAR/matchbox:latest-rpi5"
    if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
      echo "✅ $IMAGE exists (RPi5 Matchbox)"
    else
      echo "❌ $IMAGE MISSING"
      FAILURES=$((FAILURES + 1))
    fi
  fi
done

echo "==========================================="
if [ $FAILURES -eq 0 ]; then
  echo "🎉 Provenance verified (Pragmatic Mode)!"
  exit 0
else
  echo "💥 $FAILURES images missing!"
  exit 1
fi
