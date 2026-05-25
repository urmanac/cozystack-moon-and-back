#!/bin/bash
set -e

VARIANT=$1
[ -z "$VARIANT" ] && echo "Usage: $0 <variant>" && exit 1

echo "🛠️ Applying patches for variant: $VARIANT"

# Common ARM64 base patches
git apply ../../patches/04-arm64-default-platform.patch

# Variant-specific patches
if [ "$VARIANT" = "spin-only" ]; then
    git apply ../../patches/03-arm64-spin-only.patch
elif [ "$VARIANT" = "spin-hailort" ]; then
    git apply ../../patches/08-arm64-spin-hailort.patch
elif [ "$VARIANT" = "spin-tailscale" ]; then
    git apply ../../patches/01-arm64-spin-tailscale.patch
fi

# The Architecture Variables patch (02) MUST match the context of the previous patches.
echo "🛠️ Applying architecture conversion patch 02"
git apply ../../patches/02-makefile-architecture-variables.patch

# RPi5 specialized patches MUST run after 02 because they use the arm64 strings 02 provides.
if [ "$VARIANT" = "spin-hailort" ]; then
    echo "🛠️ Applying RPi5 specialized patches (09, 10)"
    git apply ../../patches/09-arm64-rpi5-spin-hailort.patch
    git apply ../../patches/10-arm64-rpi5-specialized-matchbox.patch
fi

chmod +x packages/core/talos/hack/gen-profiles.sh
chmod +x packages/core/talos/hack/gen-versions.sh

echo "✅ All patches applied successfully for $VARIANT"
