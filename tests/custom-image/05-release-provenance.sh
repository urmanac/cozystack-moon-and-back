#!/bin/bash
# tests/custom-image/05-release-provenance.sh

# This script verifies that all expected OCI images for a release are present in GHCR.
# It respects the reality that upstream components use their own versioning tags (usually 'latest' in our release build)
# while specialized assets use our release tag.

set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
RELEASE_TAG=${1:-latest}
FAILURES=0

# Helper function to check for image or artifact presence
check_exists() {
  local IMAGE=$1
  local TYPE=$2
  
  # crane manifest is more robust for both container images and OCI artifacts (like Flux/Helm)
  if crane manifest "$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists ($TYPE)"
    return 0
  else
    echo "❌ $IMAGE MISSING ($TYPE)"
    return 1
  fi
}

# Components that we EXPECT to match our RELEASE_TAG
SPECIALIZED=(
  "cozystack-operator"
  "cozystack-packages"
)

# Components that use their own upstream versioning or 'latest'
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
  check_exists "$REGISTRY/$PKG:$RELEASE_TAG" "specialized" || FAILURES=$((FAILURES + 1))
done

# Check Upstream
for ENTRY in "${UPSTREAM_PACKAGES[@]}"; do
  PKG=${ENTRY%%:*}
  TAG=${ENTRY##*:}
  check_exists "$REGISTRY/$PKG:$TAG" "upstream" || FAILURES=$((FAILURES + 1))
done

# Check Talos/Matchbox
for VAR in "${VARIANTS[@]}"; do
  check_exists "$REGISTRY/talos/cozystack-$VAR/talos:latest" "installer" || FAILURES=$((FAILURES + 1))
  check_exists "$REGISTRY/talos/cozystack-$VAR/matchbox:latest" "matchbox" || FAILURES=$((FAILURES + 1))

  # RPi5 Specialization (only for spin-hailort)
  if [ "$VAR" = "spin-hailort" ]; then
    check_exists "$REGISTRY/talos/cozystack-$VAR/talos:latest-rpi5" "rpi5-installer" || FAILURES=$((FAILURES + 1))
    check_exists "$REGISTRY/talos/cozystack-$VAR/matchbox:latest-rpi5" "rpi5-matchbox" || FAILURES=$((FAILURES + 1))
  fi
done

echo "==========================================="
if [ $FAILURES -eq 0 ]; then
  echo "🎉 All verified successfully (Pragmatic + Artifact-Aware)!"
  exit 0
else
  echo "💥 $FAILURES images missing!"
  exit 1
fi
