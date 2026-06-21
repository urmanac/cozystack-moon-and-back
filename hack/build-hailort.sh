#!/bin/bash
set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
USERNAME=${USERNAME:-yebyen}
VERSION_BASE="5.3.0"
TALOS_VERSION="v1.13.4"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$SCRIPT_DIR/../patches" && pwd)"
WORK_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Calculate a content hash of our build logic to ensure idempotency.
# This includes the patches and this script itself.
CONTENT_HASH=$(cat "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch" \
                   "$PATCH_DIR/12-hailort-v5.3.0-extension.patch" \
                   "$0" | sha256sum | cut -c1-12)

# This is our unique immutable tag for this specific code state.
UNIQUE_TAG="${VERSION_BASE}-${TALOS_VERSION}-${CONTENT_HASH}"
STABLE_TAG="${VERSION_BASE}-${TALOS_VERSION}"

echo "📂 Working in $WORK_DIR"
echo "🆔 Content Hash: $CONTENT_HASH"
echo "🎯 Unique Tag:   $UNIQUE_TAG"

# Check if the unique image already exists in registry.
# If it does, we can safely skip the 1-hour kernel build.
if skopeo inspect "docker://$REGISTRY/$USERNAME/hailort:$UNIQUE_TAG" &>/dev/null; then
    echo "✅ Verified image for this content already exists. Skipping build."
    echo "HAILORT_IMAGE=$REGISTRY/$USERNAME/hailort:$UNIQUE_TAG" > "$SCRIPT_DIR/../hailort-build.env"
    
    # If we are on main, ensure the stable tags also point to this verified artifact.
    if [ "$GITHUB_REF" = "refs/heads/main" ]; then
        echo "🏷️  Updating stable tags on main..."
        crane tag "$REGISTRY/$USERNAME/hailort:$UNIQUE_TAG" "$STABLE_TAG"
        crane tag "$REGISTRY/$USERNAME/hailort:$UNIQUE_TAG" "$VERSION_BASE"
    fi
    exit 0
fi

cd "$WORK_DIR"

# Pinned Sidero Versions for Talos v1.13.4 (Kernel 6.18.34-talos)
EXT_TAG="v1.13.4"
PKGS_HASH="54ec9fc"

# Download source tarballs
echo "📥 Downloading Sidero extensions $EXT_TAG..."
mkdir extensions && curl -sSL "https://github.com/siderolabs/extensions/archive/refs/tags/${EXT_TAG}.tar.gz" | tar xz -C extensions --strip-components=1

echo "📥 Downloading Sidero pkgs @ $PKGS_HASH..."
mkdir pkgs && curl -sSL "https://github.com/siderolabs/pkgs/archive/${PKGS_HASH}.tar.gz" | tar xz -C pkgs --strip-components=1

# Apply surgical patches and edits
echo "🛠️ Patching pkgs..."
cd pkgs
perl -0777 -pi -e 's/hailort_version: 4.23.0/hailort_version: 5.3.0/g' Pkgfile
perl -0777 -pi -e 's/hailort_sha256: 245c7157746c2fd48b2fab4a990c8fb3b786921dd72c9e5348f5b5619ee05ec3/hailort_sha256: 716043f905d8a525fc6378224241609281f04ba5bafc989bb4633129558bb5a3/g' Pkgfile
perl -0777 -pi -e 's/hailort_sha512: b5abdf3ca5cb4cbb9d3189ed6bae52d66e52dbce99ed1698ece8ff1f5f32db7560990e66bab740f2f0102e13175eb3fc0ae41162b75ee743684fb64ff845db07/hailort_sha512: ea60ff8f241f451457906db8006370fa2d346fdbc0f086310cce7143f5ca4984324ada54e760279a38df34d65de86f9b8b66568a4d83259b1699dfe8471d4162/g' Pkgfile
perl -0777 -pi -e 's/hailort_fw_sha256: 1ba9528972091ec17bebc0dc7ea2e6f4449efe70664890f6387ccbc7b60626ee/hailort_fw_sha256: 01f8624d57e6b0a9892e9c8a71c5a2d6c3b4a794fc5848c81d5443e345c3d1db/g' Pkgfile
perl -0777 -pi -e 's/hailort_fw_sha512: 6280e4bddc120ab6e9a4a4fdac529816ee1f94d343e0e0ef6c36fd474b579f85032e22b24a8f758b23028d429ef5936780fa07ed3c0abc512f5fd72985fc982c/hailort_fw_sha512: 2c19c81bc2e48a0b225e9fd937addb08f6839c0d4f45a5c3a6a8d2214b98c200503f7319c4eb9e14259669609cfae1a481fdc8ef59d4b876a08b84702dbb064d/g' Pkgfile

git init -q && git config user.email "ci@urmanac.com" && git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git apply "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch"

echo "🛠️ Patching extensions..."
cd ../extensions
git init -q && git config user.email "ci@urmanac.com" && git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git apply "$PATCH_DIR/12-hailort-v5.3.0-extension.patch"

# Isolate Targeted Packages
echo "🧹 Isolating hailort packages..."
cd ../pkgs
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'hailort' ! -name 'base' ! -name 'reproducibility' ! -name 'kernel' -exec rm -rf {} +
cd ../extensions
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'drivers' ! -name 'hack' ! -name 'reproducibility' ! -name 'internal' ! -name 'container-runtime' -exec rm -rf {} +
find drivers -maxdepth 1 -type d ! -name 'drivers' ! -name 'hailort' -exec rm -rf {} +

# macOS Compatibility Fixes
cd ..
if [ "$(uname -s)" = "Darwin" ]; then
    echo "🍎 Applying macOS fixes to Makefiles..."
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

# Detect modern GNU Make
MAKE_CMD="make"
if [ "$(uname -s)" = "Darwin" ]; then
    [ -x "$(command -v gmake)" ] && MAKE_CMD="gmake"
fi

echo "🚀 Starting fresh build for $UNIQUE_TAG..."

# Build hailort-pkg
echo "🏗️ Building hailort-pkg..."
cd pkgs
PKG_VERSION_TAG="v1.13.0-28-g${PKGS_HASH}"
$MAKE_CMD hailort-pkg REGISTRY="$REGISTRY" USERNAME="$USERNAME" TAG="$PKG_VERSION_TAG" PUSH=true PLATFORM=linux/arm64

# Build hailort extension
echo "🏗️ Building hailort extension..."
cd ../extensions
$MAKE_CMD hailort \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    PKGS="$PKG_VERSION_TAG" \
    PKGS_PREFIX="$REGISTRY/$USERNAME" \
    PUSH=true \
    PLATFORM=linux/arm64

# Extract digest for multi-tagging
DIGEST=$(jq -r '."containerimage.digest"' _out/hailort.metadata.json)

# ALWAYS tag the unique immutable tag.
# Sidero Makefiles ignore the TAG override, so we must add it explicitly.
echo "🏷️  Tagging unique content-based version: $UNIQUE_TAG"
crane tag "$REGISTRY/$USERNAME/hailort@$DIGEST" "$UNIQUE_TAG"

# Always tag with the kernel-pinned stable version if we are on main
if [ "$GITHUB_REF" = "refs/heads/main" ]; then
    echo "🏷️  Tagging official release versions..."
    crane tag "$REGISTRY/$USERNAME/hailort@$DIGEST" "$STABLE_TAG"
    crane tag "$REGISTRY/$USERNAME/hailort@$DIGEST" "$VERSION_BASE"
fi

echo "✅ Built and pushed: $REGISTRY/$USERNAME/hailort:$UNIQUE_TAG"
echo "HAILORT_IMAGE=$REGISTRY/$USERNAME/hailort:$UNIQUE_TAG" > "$SCRIPT_DIR/../hailort-build.env"
