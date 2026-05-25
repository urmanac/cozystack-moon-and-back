#!/bin/bash
# tests/custom-image/05-release-provenance.sh

# This script verifies that all expected OCI images for a release are present in GHCR.

set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
TAG=${1:-latest}
FAILURES=0

# Cozystack Packages
PACKAGES=(
  "http-cache" "mariadb" "clickhouse" "kubernetes"
  "monitoring" "cozystack-api" "cozystack-controller" "backup-controller" "backupstrategy-controller" "lineage-controller-webhook"
  "cilium" "kubeovn" "kubeovn-webhook" "kubeovn-plunger"
  "metallb" "kamaji" "multus" "bucket" "objectstorage-controller" "grafana-operator" "testing" "platform"
  "cozystack-operator"
)

# Talos and Matchbox Variants
VARIANTS=("spin-tailscale" "spin-hailort" "spin-only")

echo "🧪 Verifying Release Provenance for TAG: $TAG"
echo "==========================================="

for PKG in "${PACKAGES[@]}"; do
  IMAGE="$REGISTRY/$PKG:$TAG"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi
done

for VAR in "${VARIANTS[@]}"; do
  # Installer
  IMAGE="$REGISTRY/talos/cozystack-$VAR/talos:$TAG"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi

  # Matchbox
  IMAGE="$REGISTRY/talos/cozystack-$VAR/matchbox:$TAG"
  if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
    echo "✅ $IMAGE exists"
  else
    echo "❌ $IMAGE MISSING"
    FAILURES=$((FAILURES + 1))
  fi

  # RPi5 Specialization (only for spin-hailort)
  if [ "$VAR" = "spin-hailort" ]; then
    # RPi5 Installer
    IMAGE="$REGISTRY/talos/cozystack-$VAR/talos:$TAG-rpi5"
    if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
      echo "✅ $IMAGE exists"
    else
      echo "❌ $IMAGE MISSING"
      FAILURES=$((FAILURES + 1))
    fi

    # RPi5 Matchbox
    IMAGE="$REGISTRY/talos/cozystack-$VAR/matchbox:$TAG-rpi5"
    if skopeo inspect "docker://$IMAGE" >/dev/null 2>&1; then
      echo "✅ $IMAGE exists"
    else
      echo "❌ $IMAGE MISSING"
      FAILURES=$((FAILURES + 1))
    fi
  fi
done

echo "==========================================="
if [ $FAILURES -eq 0 ]; then
  echo "🎉 All verified successfully!"
  exit 0
else
  echo "💥 $FAILURES images missing!"
  exit 1
fi
