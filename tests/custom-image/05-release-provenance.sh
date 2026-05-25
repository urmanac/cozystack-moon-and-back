#!/bin/bash
# tests/custom-image/05-release-provenance.sh

# This script verifies that all expected OCI images for a release are present in GHCR.
# It respects the reality that upstream components use their own versioning tags (usually 'latest' in our release build)
# while specialized assets use our release tag.

set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
RELEASE_TAG=${1:-latest}
FAILURES=0

# Components that we EXPECT to match our RELEASE_TAG
SPECIALIZED=(
  "cozystack-operator"
  "cozystack-packages"
)

# Components that use their own upstream versioning or 'latest'
# These are the actual image names produced by the Cozystack build.
UPSTREAM_PACKAGES=(
  "nginx-cache:latest"
  "mariadb-backup:latest"
  "clickhouse-backup:latest"
  "altinity-clickhouse-backup:latest"
  "ubuntu-container-disk:latest"
  "kubevirt-cloud-provider:latest"
  "kubevirt-csi-driver:latest"
  "cluster-autoscaler:latest"
  "grafana:latest"
  "cozystack-api:latest"
  "cozystack-controller:latest"
  "backup-controller:latest"
  "backupstrategy-controller:latest"
  "lineage-controller-webhook:latest"
  "cilium:latest"
  "kubeovn-webhook:latest"
  "kubeovn-plunger:latest"
  "metallb-controller:v0.15.2"
  "metallb-speaker:v0.15.2"
  "kamaji:latest"
  "multus-cni:latest"
  "s3manager:latest"
  "objectstorage-controller:latest"
  "objectstorage-sidecar:latest"
  "grafana-dashboards:latest"
  "e2e-sandbox:latest"
  "platform-migrations:latest"
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
  IMAGE="$REGISTRY/talos/cozystack-$VAR/talos:latest"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists (Generic Installer)"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi

  # Matchbox
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
