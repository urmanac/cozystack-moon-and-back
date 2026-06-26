#!/bin/bash
set -e

echo "=== PATCH VALIDATION SCRIPT ==="
echo "Testing patch application in their respective contexts..."

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="$WORKSPACE_DIR/patches"

# Clean up any previous test
rm -rf /tmp/cozystack-patch-test
mkdir -p /tmp/cozystack-patch-test
cd /tmp/cozystack-patch-test

COZYSTACK_REF=$(cut -d- -f1 "$WORKSPACE_DIR/VERSION")

# Helper function to reset checkout
reset_cozystack() {
    cd /tmp/cozystack-patch-test/cozystack
    git reset --hard
    git clean -fd
}

echo ""
echo "=== 1. CLONING UPSTREAM COZYSTACK ==="
git clone https://github.com/cozystack/cozystack.git
cd cozystack
git checkout "$COZYSTACK_REF"

echo ""
echo "=== 2. VALIDATING COZYSTACK GENERAL PACKAGES BUILD CONTEXT ==="
echo "Applying package build patches (04, 05, 06, 07, 11, 14)..."
reset_cozystack
git apply "$PATCH_DIR/04-arm64-default-platform.patch"
git apply "$PATCH_DIR/05-arm64-dashboard.patch"
git apply "$PATCH_DIR/06-kubeovn-manifest-list-retag.patch"
git apply "$PATCH_DIR/07-arm64-skip-amd64-only-builds.patch"
git apply "$PATCH_DIR/11-fix-tagging-logic.patch"
git apply "$PATCH_DIR/14-arm64-linstor.patch"
echo "✅ Package build patches applied cleanly!"

# Save this patched state for catalog validation later
mkdir -p /tmp/cozystack-patch-test/patched-packages-tree
cp -r . /tmp/cozystack-patch-test/patched-packages-tree/

echo ""
echo "=== 3. VALIDATING TALOS OS VARIANTS ==="

echo "Testing variant: spin-only (04, 11, 03, 02)..."
reset_cozystack
git apply "$PATCH_DIR/04-arm64-default-platform.patch"
git apply "$PATCH_DIR/11-fix-tagging-logic.patch"
git apply "$PATCH_DIR/03-arm64-spin-only.patch"
git apply "$PATCH_DIR/02-makefile-architecture-variables.patch"
echo "✅ Variant spin-only applied cleanly!"

echo "Testing variant: spin-hailort (04, 11, 08, 02, 09, 10)..."
reset_cozystack
git apply "$PATCH_DIR/04-arm64-default-platform.patch"
git apply "$PATCH_DIR/11-fix-tagging-logic.patch"
git apply "$PATCH_DIR/08-arm64-spin-hailort.patch"
git apply "$PATCH_DIR/02-makefile-architecture-variables.patch"
git apply "$PATCH_DIR/09-arm64-rpi5-spin-hailort.patch"
git apply "$PATCH_DIR/10-arm64-rpi5-specialized-matchbox.patch"
echo "✅ Variant spin-hailort applied cleanly!"

echo "Testing variant: spin-tailscale (04, 11, 01, 02)..."
reset_cozystack
git apply "$PATCH_DIR/04-arm64-default-platform.patch"
git apply "$PATCH_DIR/11-fix-tagging-logic.patch"
git apply "$PATCH_DIR/01-arm64-spin-tailscale.patch"
git apply "$PATCH_DIR/02-makefile-architecture-variables.patch"
echo "✅ Variant spin-tailscale applied cleanly!"

echo ""
echo "=== 4. VALIDATING UPSTREAM SIDEROLABS REPOSITORIES ==="

# Get versions/commits from hack/build-hailort.sh
EXT_TAG="v1.13.5"
PKGS_HASH="6b315f7"

echo "Testing patch 12 against siderolabs/extensions @ $EXT_TAG..."
cd /tmp/cozystack-patch-test
mkdir extensions && curl -sSL "https://github.com/siderolabs/extensions/archive/refs/tags/${EXT_TAG}.tar.gz" | tar xz -C extensions --strip-components=1
cd extensions
git init -q && git config user.email "ci@urmanac.com" && git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git apply "$PATCH_DIR/12-hailort-v5.3.0-extension.patch"
echo "✅ Patch 12 applied cleanly!"

echo "Testing patch 13 against siderolabs/pkgs @ $PKGS_HASH..."
cd /tmp/cozystack-patch-test
mkdir pkgs && curl -sSL "https://github.com/siderolabs/pkgs/archive/${PKGS_HASH}.tar.gz" | tar xz -C pkgs --strip-components=1
cd pkgs
# Apply the inline perl edits from build-hailort.sh first
perl -0777 -pi -e 's/hailort_version: 4.23.0/hailort_version: 5.3.0/g' Pkgfile
perl -0777 -pi -e 's/hailort_sha256: 245c7157746c2fd48b2fab4a990c8fb3b786921dd72c9e5348f5b5619ee05ec3/hailort_sha256: 716043f905d8a525fc6378224241609281f04ba5bafc989bb4633129558bb5a3/g' Pkgfile
perl -0777 -pi -e 's/hailort_sha512: b5abdf3ca5cb4cbb9d3189ed6bae52d66e52dbce99ed1698ece8ff1f5f32db7560990e66bab740f2f0102e13175eb3fc0ae41162b75ee743684fb64ff845db07/hailort_sha512: ea60ff8f241f451457906db8006370fa2d346fdbc0f086310cce7143f5ca4984324ada54e760279a38df34d65de86f9b8b66568a4d83259b1699dfe8471d4162/g' Pkgfile
perl -0777 -pi -e 's/hailort_fw_sha256: 1ba9528972091ec17bebc0dc7ea2e6f4449efe70664890f6387ccbc7b60626ee/hailort_fw_sha256: 01f8624d57e6b0a9892e9c8a71c5a2d6c3b4a794fc5848c81d5443e345c3d1db/g' Pkgfile
perl -0777 -pi -e 's/hailort_fw_sha512: 6280e4bddc120ab6e9a4a4fdac529816ee1f94d343e0e0ef6c36fd474b579f85032e22b24a8f758b23028d429ef5936780fa07ed3c0abc512f5fd72985fc982c/hailort_fw_sha512: 2c19c81bc2e48a0b225e9fd937addb08f6839c0d4f45a5c3a6a8d2214b98c200503f7319c4eb9e14259669609cfae1a481fdc8ef59d4b876a08b84702dbb064d/g' Pkgfile
git init -q && git config user.email "ci@urmanac.com" && git config user.name "CozyStack CI"
git add . && git commit -m "initial" -q
git apply "$PATCH_DIR/13-hailort-v5.3.0-pkgs.patch"
echo "✅ Patch 13 applied cleanly!"

echo ""
echo "=== 5. VALIDATING PARENT PATCH SYNTAX ==="
python3 "$WORKSPACE_DIR/hack/validate-patch-syntax.py" "$PATCH_DIR"

echo ""
echo "=== 6. VALIDATING NESTED PATCH SYNTAX ==="
# Validate nested patches inside our main patched tree
cd /tmp/cozystack-patch-test/patched-packages-tree
if ! python3 "$WORKSPACE_DIR/hack/validate-patch-syntax.py" .; then
    echo "❌ Malformed/corrupt generated nested patch detected!"
    exit 1
fi

echo ""
echo "=== 7. VALIDATING NESTED PATCH APPLICATION AGAINST UPSTREAM ==="
if ! python3 "$WORKSPACE_DIR/hack/validate-upstream-patches.py" . "$WORKSPACE_DIR"; then
    echo "❌ Nested patch failed to apply to upstream codebase!"
    exit 1
fi

echo ""
echo "=== 8. VALIDATING PACKAGE CATALOG SYNCHRONIZATION ==="
if ! python3 "$WORKSPACE_DIR/hack/validate-package-catalog.py" . "$WORKSPACE_DIR"; then
    echo "❌ Package catalog mismatch detected!"
    exit 1
fi

echo ""
echo "✅ ALL PATCHES AND REPOS VALIDATED SUCCESSFULLY!"

echo ""
echo "=== CLEANUP ==="
echo "Test completed. Cleaning up..."
cd /
rm -rf /tmp/cozystack-patch-test
echo "Done!"