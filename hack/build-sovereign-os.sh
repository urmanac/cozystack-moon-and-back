#!/bin/bash
set -e

REGISTRY=${REGISTRY:-ghcr.io/urmanac/cozystack-assets}
USERNAME=${USERNAME:-yebyen}
VERSION_BASE="5.3.0"
TALOS_VERSION="v1.13.4"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$(cd "$SCRIPT_DIR/../patches" && pwd)"
# Create working directory inside the mounted /tmp/buildx-cache volume if available.
# This prevents Docker-in-Docker volume mount issues (where the host docker daemon
# cannot see files created in the runner container's ephemeral /tmp filesystem).
PARENT_TEMP="/tmp"
[ -d "/tmp/buildx-cache" ] && [ -w "/tmp/buildx-cache" ] && PARENT_TEMP="/tmp/buildx-cache"
WORK_DIR=$(mktemp -d -p "$PARENT_TEMP")

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Calculate a content hash of our build logic to ensure idempotency.
CONTENT_HASH=$(cat "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch" \
                   "$PATCH_DIR/12-hailort-v5.3.0-extension.patch" \
                   "$0" | sha256sum | cut -c1-12)

UNIQUE_TAG="${VERSION_BASE}-${TALOS_VERSION}-${CONTENT_HASH}"
STABLE_TAG="${VERSION_BASE}-${TALOS_VERSION}"
REQUIRED_EXTENSIONS=(hailort drbd zfs)

# We rely on the persistent Buildx builder container's internal cache, so CI_ARGS is not needed.
export CI_ARGS=""

echo "📂 Working in $WORK_DIR"
echo "🆔 Content Hash: $CONTENT_HASH"
echo "🎯 Unique Tag:   $UNIQUE_TAG"

all_required_present=true
for extension in "${REQUIRED_EXTENSIONS[@]}"; do
    if ! skopeo inspect "docker://$REGISTRY/$USERNAME/$extension:$UNIQUE_TAG" &>/dev/null; then
        all_required_present=false
        break
    fi
done

if [ "$all_required_present" = "true" ] && \
   skopeo inspect "docker://$REGISTRY/$USERNAME/installer:$UNIQUE_TAG" &>/dev/null && \
   skopeo inspect "docker://$REGISTRY/$USERNAME/imager:$UNIQUE_TAG" &>/dev/null; then
    echo "✅ Verified sovereign images already exist. Skipping build."
    echo "INSTALLER_IMAGE=$REGISTRY/$USERNAME/installer:$UNIQUE_TAG" > "$SCRIPT_DIR/../sovereign-os.env"
    for extension in "${REQUIRED_EXTENSIONS[@]}"; do
        echo "${extension^^}_IMAGE=$REGISTRY/$USERNAME/$extension:$UNIQUE_TAG" >> "$SCRIPT_DIR/../sovereign-os.env"
    done
    echo "IMAGER_IMAGE=$REGISTRY/$USERNAME/imager:$UNIQUE_TAG" >> "$SCRIPT_DIR/../sovereign-os.env"
    
    if [ "$GITHUB_REF" = "refs/heads/main" ]; then
        echo "🏷️  Updating stable tags on main..."
        for extension in "${REQUIRED_EXTENSIONS[@]}"; do
            DIGEST_EXTENSION=$(skopeo inspect "docker://$REGISTRY/$USERNAME/$extension:$UNIQUE_TAG" --format '{{.Digest}}')
            crane tag "$REGISTRY/$USERNAME/$extension@$DIGEST_EXTENSION" "$STABLE_TAG"
            crane tag "$REGISTRY/$USERNAME/$extension@$DIGEST_EXTENSION" "$VERSION_BASE"
        done

        DIGEST_INSTALLER=$(skopeo inspect "docker://$REGISTRY/$USERNAME/installer:$UNIQUE_TAG" --format '{{.Digest}}')
        crane tag "$REGISTRY/$USERNAME/installer@$DIGEST_INSTALLER" "$STABLE_TAG"
        crane tag "$REGISTRY/$USERNAME/installer@$DIGEST_INSTALLER" "$VERSION_BASE"

        DIGEST_IMAGER=$(skopeo inspect "docker://$REGISTRY/$USERNAME/imager:$UNIQUE_TAG" --format '{{.Digest}}')
        crane tag "$REGISTRY/$USERNAME/imager@$DIGEST_IMAGER" "$STABLE_TAG"
        crane tag "$REGISTRY/$USERNAME/imager@$DIGEST_IMAGER" "$VERSION_BASE"
    fi
    exit 0
fi

cd "$WORK_DIR"

EXT_TAG="v1.13.4"
PKGS_HASH="54ec9fc"

echo "📥 Downloading Sidero source trees..."
mkdir extensions && curl -sSL "https://github.com/siderolabs/extensions/archive/refs/tags/${EXT_TAG}.tar.gz" | tar xz -C extensions --strip-components=1
mkdir pkgs && curl -sSL "https://github.com/siderolabs/pkgs/archive/${PKGS_HASH}.tar.gz" | tar xz -C pkgs --strip-components=1
mkdir talos && curl -sSL "https://github.com/siderolabs/talos/archive/refs/tags/${EXT_TAG}.tar.gz" | tar xz -C talos --strip-components=1

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

echo "🧹 Isolating targeted build directories..."
cd ../pkgs
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'hailort' ! -name 'drbd' ! -name 'zfs' ! -name 'base' ! -name 'reproducibility' ! -name 'kernel' -exec rm -rf {} +
cd ../extensions
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'drivers' ! -name 'storage' ! -name 'hack' ! -name 'reproducibility' ! -name 'internal' ! -name 'container-runtime' -exec rm -rf {} +
find drivers -maxdepth 1 -type d ! -name 'drivers' ! -name 'hailort' -exec rm -rf {} +

cd ..
echo "🛠️ Initializing talos git repository..."
cd talos
git init -q && git config user.email "ci@urmanac.com" && git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git tag "$EXT_TAG"
cd ..

if [ "$(uname -s)" = "Darwin" ]; then
    perl -pi -e 's/^CI_RELEASE_TAG :=.*/CI_RELEASE_TAG :=/' pkgs/Makefile extensions/Makefile talos/Makefile
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')
curl -sSL https://github.com/siderolabs/bldr/releases/download/v0.6.0/bldr-${OS}-${ARCH} -o bldr
chmod +x bldr
export PATH="$PWD:$PATH"

MAKE_CMD="make"
[ "$(uname -s)" = "Darwin" ] && [ -x "$(command -v gmake)" ] && MAKE_CMD="gmake"

PKG_VERSION_TAG="v1.13.0-28-g${PKGS_HASH}"

# Step 1: Compile the sovereign kernel and all package images consumed by extensions.
# First-run CI must publish drbd-pkg/zfs-pkg before the extension build can reference them.
echo "🏗️ Building sovereign kernel and required package images..."
cd pkgs
$MAKE_CMD kernel hailort-pkg drbd-pkg zfs-pkg SOURCE_DATE_EPOCH=1716646524 REGISTRY="$REGISTRY" USERNAME="$USERNAME" TAG="$PKG_VERSION_TAG" PUSH=true PLATFORM=linux/arm64

cd ..
# Step 1.5: Merge official Sidero Labs amd64 kernel with our custom arm64 kernel into a multi-arch index
echo "🔀 Creating multi-arch manifest list for kernel..."
AMD64_KERNEL_DIGEST=$(crane digest ghcr.io/siderolabs/kernel:$PKG_VERSION_TAG --platform linux/amd64)
ARM64_KERNEL_DIGEST=$(crane digest $REGISTRY/$USERNAME/kernel:$PKG_VERSION_TAG)
crane index append \
    -m "ghcr.io/siderolabs/kernel@$AMD64_KERNEL_DIGEST" \
    -m "$REGISTRY/$USERNAME/kernel@$ARM64_KERNEL_DIGEST" \
    -t "$REGISTRY/$USERNAME/kernel:$PKG_VERSION_TAG"

# Step 2: Compile required extensions against the sovereign kernel (signed with the same key context)
echo "🏗️ Building required extensions (hailort, drbd, zfs)..."
cd extensions
$MAKE_CMD hailort drbd zfs SOURCE_DATE_EPOCH=1716646524 \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    TAG="$TALOS_VERSION" \
    PKGS="$PKG_VERSION_TAG" \
    PKGS_PREFIX="$REGISTRY/$USERNAME" \
    PUSH=true \
    PLATFORM=linux/arm64

for extension in "${REQUIRED_EXTENSIONS[@]}"; do
    METADATA_FILE="_out/${extension}.metadata.json"
    if [ ! -f "$METADATA_FILE" ]; then
        echo "❌ Missing metadata for extension '$extension' at $METADATA_FILE"
        exit 1
    fi

    DIGEST_EXTENSION=$(jq -r '."containerimage.digest"' "$METADATA_FILE")
    crane tag "$REGISTRY/$USERNAME/$extension@$DIGEST_EXTENSION" "$UNIQUE_TAG"
done

# Step 3: Build a custom Talos Installer that wraps our sovereign kernel
echo "🏗️ Building custom installer..."
cd ../talos
$MAKE_CMD installer-base imager installer SOURCE_DATE_EPOCH=1716646524 \
    REGISTRY="$REGISTRY" \
    USERNAME="$USERNAME" \
    TAG="$TALOS_VERSION" \
    PKG_KERNEL="$REGISTRY/$USERNAME/kernel:$PKG_VERSION_TAG" \
    PUSH=true \
    PLATFORM=linux/arm64

echo "🏷️  Tagging custom installer images to content-based unique versions..."
DIGEST_INSTALLER_BASE=$(crane digest "$REGISTRY/$USERNAME/installer-base:$TALOS_VERSION")
crane tag "$REGISTRY/$USERNAME/installer-base@$DIGEST_INSTALLER_BASE" "$UNIQUE_TAG"

DIGEST_IMAGER=$(crane digest "$REGISTRY/$USERNAME/imager:$TALOS_VERSION")
crane tag "$REGISTRY/$USERNAME/imager@$DIGEST_IMAGER" "$UNIQUE_TAG"

DIGEST_INSTALLER=$(crane digest "$REGISTRY/$USERNAME/installer:$TALOS_VERSION")
crane tag "$REGISTRY/$USERNAME/installer@$DIGEST_INSTALLER" "$UNIQUE_TAG"

if [ "$GITHUB_REF" = "refs/heads/main" ]; then
    echo "🏷️  Tagging official release versions..."
    for extension in "${REQUIRED_EXTENSIONS[@]}"; do
        DIGEST_EXTENSION=$(jq -r '."containerimage.digest"' "../extensions/_out/${extension}.metadata.json")
        crane tag "$REGISTRY/$USERNAME/$extension@$DIGEST_EXTENSION" "$STABLE_TAG"
        crane tag "$REGISTRY/$USERNAME/$extension@$DIGEST_EXTENSION" "$VERSION_BASE"
    done
    crane tag "$REGISTRY/$USERNAME/installer@$DIGEST_INSTALLER" "$STABLE_TAG"
    crane tag "$REGISTRY/$USERNAME/installer@$DIGEST_INSTALLER" "$VERSION_BASE"
fi

echo "✅ Built and pushed sovereign OS artifacts."
echo "INSTALLER_IMAGE=$REGISTRY/$USERNAME/installer:$UNIQUE_TAG" > "$SCRIPT_DIR/../sovereign-os.env"
for extension in "${REQUIRED_EXTENSIONS[@]}"; do
    echo "${extension^^}_IMAGE=$REGISTRY/$USERNAME/$extension:$UNIQUE_TAG" >> "$SCRIPT_DIR/../sovereign-os.env"
done
echo "IMAGER_IMAGE=$REGISTRY/$USERNAME/imager:$UNIQUE_TAG" >> "$SCRIPT_DIR/../sovereign-os.env"
