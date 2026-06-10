#!/bin/bash
set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
USERNAME=${USERNAME:-talos}
HAILORT_VERSION="5.3.0-v1.13.3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$SCRIPT_DIR/../patches" && pwd)"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "📂 Working in $WORK_DIR"
cd "$WORK_DIR"

# Clone repos at specific tags to match Talos v1.13.3 kernel (6.18.33-talos)
git clone --depth 1 --branch v1.13.3 https://github.com/siderolabs/extensions.git

# v1.13.0-23-g8c18616 is a git description, not a tag. We clone and checkout the hash.
git clone https://github.com/siderolabs/pkgs.git
cd pkgs
git checkout 8c18616
cd ..

# Apply patches
echo "🛠️ Patching pkgs..."
cd pkgs
git apply "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch"

echo "🛠️ Patching extensions..."
cd ../extensions
git apply "$PATCH_DIR/12-hailort-v5.3.0-extension.patch"

# macOS Compatibility Fixes
cd ..
if [ "$(uname -s)" = "Darwin" ]; then
    echo "🍎 Applying macOS fixes to Makefiles..."
    # The GNU sed command in CI_RELEASE_TAG breaks BSD sed. We don't need it.
    sed -i '' 's/CI_RELEASE_TAG := .*/CI_RELEASE_TAG :=/' pkgs/Makefile
    sed -i '' 's/CI_RELEASE_TAG := .*/CI_RELEASE_TAG :=/' extensions/Makefile
fi

# Download bldr
echo "📥 Downloading bldr..."
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
curl -sSL https://github.com/siderolabs/bldr/releases/download/v0.6.0/bldr-${OS}-${ARCH} -o bldr
chmod +x bldr
export PATH="$PWD:$PATH"

# Calculate versions
cd pkgs
PKG_VERSION=$(bldr eval --target hailort-pkg '{{.VERSION}}')
PKG_IMAGE="$REGISTRY/$USERNAME/hailort-pkg:$PKG_VERSION"

cd ../extensions
EXT_VERSION="$HAILORT_VERSION"
EXT_IMAGE="$REGISTRY/$USERNAME/hailort:$EXT_VERSION"

echo "🎯 Target Extension Image: $EXT_IMAGE"

# Check if image exists in registry
if skopeo inspect "docker://$EXT_IMAGE" &>/dev/null; then
    echo "✅ Image already exists in registry. Skipping build."
    echo "HAILORT_IMAGE=$EXT_IMAGE" > "$SCRIPT_DIR/../hailort-build.env"
    exit 0
fi

# Detect modern GNU Make
MAKE_CMD="make"
if [ "$(uname -s)" = "Darwin" ]; then
    if command -v gmake &> /dev/null; then
        MAKE_CMD="gmake"
    else
        echo "❌ Error: macOS default 'make' (v3.81) is too old for Sidero Makefiles."
        echo "💡 Please install GNU Make via Homebrew: brew install make"
        echo "   Then re-run this script."
        exit 1
    fi
fi

echo "🚀 Image not found. Starting build (this may take a while as it builds the kernel)..."

# Build hailort-pkg
echo "🏗️ Building hailort-pkg..."
cd ../pkgs
$MAKE_CMD hailort-pkg REGISTRY="$REGISTRY" USERNAME="$USERNAME" PUSH=true PLATFORM=linux/arm64

# Build hailort extension
echo "🏗️ Building hailort extension..."
cd ../extensions
$MAKE_CMD hailort \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    PKGS="$PKG_VERSION" \
    PKGS_PREFIX="$REGISTRY/$USERNAME" \
    PUSH=true \
    PLATFORM=linux/arm64

echo "✅ Built and pushed: $EXT_IMAGE"
echo "HAILORT_IMAGE=$EXT_IMAGE" > "$SCRIPT_DIR/../hailort-build.env"
