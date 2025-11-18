#!/bin/bash
set -e

echo "=== PATCH VALIDATION SCRIPT ==="
echo "Testing patch application without full build..."

# Clean up any previous test
rm -rf /tmp/cozystack-patch-test
mkdir -p /tmp/cozystack-patch-test
cd /tmp/cozystack-patch-test

echo ""
echo "=== 1. CLONING UPSTREAM COZYSTACK ==="
git clone https://github.com/cozystack/cozystack.git
cd cozystack
git checkout main

echo ""
echo "=== 2. CHECKING FILE STATE BEFORE PATCH ==="
echo "gen-profiles.sh EXTENSIONS line:"
grep -n "EXTENSIONS=" packages/core/installer/hack/gen-profiles.sh

echo ""
echo "gen-profiles.sh arch line:"
grep -n "arch:" packages/core/installer/hack/gen-profiles.sh

echo ""
echo "gen-versions.sh EXTENSIONS line:"
grep -n "EXTENSIONS=" packages/core/installer/hack/gen-versions.sh

echo ""
echo "=== 3. APPLYING ALL PATCHES ==="
# Find all patches in our patches directory
PATCH_DIR="/Users/yebyen/u/c/cozystack-moon-and-back/patches"
PATCHES=($(find "$PATCH_DIR" -name "*.patch" | sort))

echo "Found ${#PATCHES[@]} patches to validate:"
for patch in "${PATCHES[@]}"; do
    echo "  - $(basename "$patch")"
done

echo ""
echo "=== 3a. DRY RUN: Checking all patches... ==="
ALL_PATCHES_VALID=true
for patch in "${PATCHES[@]}"; do
    echo "Checking $(basename "$patch")..."
    if git apply --check "$patch"; then
        echo "✅ $(basename "$patch") check passed!"
    else
        echo "❌ $(basename "$patch") check failed!"
        ALL_PATCHES_VALID=false
        
        echo "Trying with --ignore-whitespace..."
        if git apply --check --ignore-whitespace "$patch"; then
            echo "⚠️  $(basename "$patch") needs --ignore-whitespace"
        else
            echo "❌ $(basename "$patch") completely incompatible"
        fi
    fi
    echo ""
done

if [ "$ALL_PATCHES_VALID" = true ]; then
    echo "✅ ALL PATCHES PASSED DRY RUN!"
else
    echo "❌ Some patches failed validation"
    echo "Continuing with actual application to see detailed failures..."
fi

echo ""
echo "=== 3b. ACTUAL APPLICATION: Applying all patches... ==="
APPLIED_PATCHES=()
FAILED_PATCHES=()

for patch in "${PATCHES[@]}"; do
    echo "Applying $(basename "$patch")..."
    if git apply -v "$patch"; then
        echo "✅ $(basename "$patch") applied successfully!"
        APPLIED_PATCHES+=("$patch")
    else
        echo "❌ $(basename "$patch") application failed"
        FAILED_PATCHES+=("$patch")
        
        echo "Git status after failure:"
        git status
        echo ""
    fi
    echo ""
done

echo "=== PATCH APPLICATION SUMMARY ==="
echo "✅ Applied successfully: ${#APPLIED_PATCHES[@]} patches"
for patch in "${APPLIED_PATCHES[@]}"; do
    echo "  - $(basename "$patch")"
done

if [ ${#FAILED_PATCHES[@]} -gt 0 ]; then
    echo "❌ Failed to apply: ${#FAILED_PATCHES[@]} patches"
    for patch in "${FAILED_PATCHES[@]}"; do
        echo "  - $(basename "$patch")"
    done
fi

echo ""
echo "=== 4. VERIFYING CHANGES ==="
if [ ${#FAILED_PATCHES[@]} -eq 0 ]; then
    echo "All patches applied successfully! Verifying changes..."
    
    echo ""
    echo "Modified files:"
    git status --porcelain
    
    echo ""
    echo "gen-profiles.sh EXTENSIONS line (should show 'spin tailscale'):"
    grep -n "EXTENSIONS=" packages/core/installer/hack/gen-profiles.sh
    
    echo ""
    echo "gen-profiles.sh arch line (should show 'arm64'):"
    grep -n "arch:" packages/core/installer/hack/gen-profiles.sh
    
    echo ""
    echo "gen-versions.sh EXTENSIONS line (should show 'spin tailscale'):"
    grep -n "EXTENSIONS=" packages/core/installer/hack/gen-versions.sh
    
    echo ""
    echo "System extensions in profile (should include SPIN and TAILSCALE):"
    grep -A10 "systemExtensions:" packages/core/installer/hack/gen-profiles.sh
    
    echo ""
    echo "Makefile asset references (should show arm64):"
    grep -n "installer-.*\.tar\|kernel-.*\|initramfs-.*\.xz" packages/core/installer/Makefile
    
    echo ""
    echo "✅ ALL PATCHES VALIDATION SUCCESSFUL!"
else
    echo "❌ Some patches failed - see details above"
    echo ""
    echo "Final git status:"
    git status
    
    echo ""
    echo "Final diff of applied changes:"
    git diff
fi

echo ""
echo "=== CLEANUP ==="
echo "Test completed. Cleaning up..."
cd /
rm -rf /tmp/cozystack-patch-test
echo "Done!"