#!/bin/bash
set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
USERNAME=${USERNAME:-talos}
HAILORT_VERSION="5.3.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$SCRIPT_DIR/../patches" && pwd)"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "📂 Working in $WORK_DIR"
cd "$WORK_DIR"

# Clone repos
git clone --depth 1 https://github.com/siderolabs/pkgs.git
git clone --depth 1 https://github.com/siderolabs/extensions.git

# Apply patches
echo "🛠️ Patching pkgs..."
cd pkgs
git apply "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch"

echo "🛠️ Patching extensions..."
cd ../extensions
git apply "$PATCH_DIR/12-hailort-v5.3.0-extension.patch"

# Download bldr if not present
if ! command -v bldr &> /dev/null; then
    echo "📥 Downloading bldr..."
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
    curl -sSL https://github.com/siderolabs/bldr/releases/download/v0.6.0/bldr-${OS}-${ARCH} -o bldr
    chmod +x bldr
    export PATH="$PWD:$PATH"
fi

# Build hailort-pkg
echo "🏗️ Building hailort-pkg..."
cd ../pkgs
make hailort-pkg REGISTRY="$REGISTRY" USERNAME="$USERNAME" PUSH=true

# Get the version/tag of the built pkg
PKG_VERSION=$(bldr eval --target hailort-pkg '{{.VERSION}}')
PKG_IMAGE="$REGISTRY/$USERNAME/hailort-pkg:$PKG_VERSION"
echo "✅ Built pkg: $PKG_IMAGE"

# Build hailort extension
echo "🏗️ Building hailort extension..."
cd ../extensions

# We need to tell bldr to use our local pkgs build
# One way is to update Pkgfile or Makefile.
# But bldr can take build-args.
# The hailort extension uses: {{ .BUILD_ARG_PKGS_PREFIX }}/hailort-pkg:{{ .BUILD_ARG_PKGS }}

# We can override PKGS in the make call
make hailort \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    PKGS="$PKG_VERSION" \
    PKGS_PREFIX="$REGISTRY/$USERNAME" \
    PUSH=true

EXT_VERSION=$(bldr eval --target hailort --build-arg PKGS="$PKG_VERSION" --build-arg PKGS_PREFIX="$REGISTRY/$USERNAME" '{{.VERSION}}')
EXT_IMAGE="$REGISTRY/$USERNAME/hailort:$EXT_VERSION"

echo "✅ Built extension: $EXT_IMAGE"
echo "HAILORT_IMAGE=$EXT_IMAGE" > "$SCRIPT_DIR/../hailort-build.env"
