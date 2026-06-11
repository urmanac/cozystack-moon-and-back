#!/bin/bash
set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
USERNAME=${USERNAME:-yebyen}
HAILORT_VERSION="5.3.0-v1.13.3"

# Pinned Sidero Versions for Talos v1.13.3 (Kernel 6.18.33-talos)
EXT_TAG="v1.13.3"
PKGS_HASH="8c18616"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$SCRIPT_DIR/../patches" && pwd)"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "📂 Working in $WORK_DIR"
cd "$WORK_DIR"

# Download source tarballs (much faster than git clone)
echo "📥 Downloading Sidero extensions $EXT_TAG..."
mkdir extensions && curl -sSL "https://github.com/siderolabs/extensions/archive/refs/tags/${EXT_TAG}.tar.gz" | tar xz -C extensions --strip-components=1

echo "📥 Downloading Sidero pkgs @ $PKGS_HASH..."
mkdir pkgs && curl -sSL "https://github.com/siderolabs/pkgs/archive/${PKGS_HASH}.tar.gz" | tar xz -C pkgs --strip-components=1

# Apply surgical patches and edits
echo "🛠️ Patching pkgs..."
cd pkgs
git init -q
git config user.email "ci@urmanac.com"
git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q # git apply needs a repo context sometimes
git apply "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch"

echo "🛠️ Patching extensions..."
cd ../extensions
git init -q
git config user.email "ci@urmanac.com"
git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git apply "$PATCH_DIR/12-hailort-v5.3.0-extension.patch"

# Isolate Targeted Packages
# bldr performs strict validation on ALL packages in the tree.
# We must delete unrelated broken packages so bldr skips validating them.
echo "🧹 Isolating hailort packages..."
cd ../pkgs
# Keep only hailort, base (for kernel-build), reproducibility (for common vars), and kernel
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'hailort' ! -name 'base' ! -name 'reproducibility' ! -name 'kernel' -exec rm -rf {} +

cd ../extensions
# Keep hailort driver, internal (for base), reproducibility, and container-runtime (for common vars)
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'drivers' ! -name 'hack' ! -name 'reproducibility' ! -name 'internal' ! -name 'container-runtime' -exec rm -rf {} +
# Inside drivers/, keep only hailort
find drivers -maxdepth 1 -type d ! -name 'drivers' ! -name 'hailort' -exec rm -rf {} +

# macOS Compatibility Fixes
cd ..
if [ "$(uname -s)" = "Darwin" ]; then
    echo "🍎 Applying macOS fixes to Makefiles..."
    # The GNU sed command in CI_RELEASE_TAG breaks BSD sed. We don't need it.
    perl -pi -e 's/^CI_RELEASE_TAG :=.*/CI_RELEASE_TAG :=/' pkgs/Makefile
    perl -pi -e 's/^CI_RELEASE_TAG :=.*/CI_RELEASE_TAG :=/' extensions/Makefile
fi

# Download bldr
echo "📥 Downloading bldr..."
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
curl -sSL https://github.com/siderolabs/bldr/releases/download/v0.6.0/bldr-${OS}-${ARCH} -o bldr
chmod +x bldr
export PATH="$PWD:$PATH"

# Calculate versions
# Tags are now predictable based on pinning
PKG_VERSION="v1.13.0-23-g${PKGS_HASH}"
PKG_IMAGE="$REGISTRY/$USERNAME/hailort-pkg:$PKG_VERSION"

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
        exit 1
    fi
fi

echo "🚀 Starting build (Kernel compilation is cached in Buildx)..."

# Build hailort-pkg
echo "🏗️ Building hailort-pkg..."
cd pkgs
$MAKE_CMD hailort-pkg REGISTRY="$REGISTRY" USERNAME="$USERNAME" TAG="$PKG_VERSION" PUSH=true PLATFORM=linux/arm64

# Build hailort extension
echo "🏗️ Building hailort extension..."
cd ../extensions
$MAKE_CMD hailort \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    TAG="$EXT_VERSION" \
    PKGS="$PKG_VERSION" \
    PKGS_PREFIX="$REGISTRY/$USERNAME" \
    PUSH=true \
    PLATFORM=linux/arm64

echo "✅ Built and pushed: $EXT_IMAGE"
echo "HAILORT_IMAGE=$EXT_IMAGE" > "$SCRIPT_DIR/../hailort-build.env"
