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
echo "=== 3. APPLYING PATCH ==="
# Copy our patch to test location
cp /Users/yebyen/u/c/cozystack-moon-and-back/patches/01-arm64-spin-tailscale.patch ./test.patch

echo "Trying git apply --check (dry run)..."
if git apply --check test.patch; then
    echo "✅ Patch check passed!"
else
    echo "❌ Patch check failed!"
    echo ""
    echo "Trying with --ignore-whitespace..."
    if git apply --check --ignore-whitespace test.patch; then
        echo "✅ Patch check passed with --ignore-whitespace!"
    else
        echo "❌ Patch check failed even with --ignore-whitespace"
        echo ""
        echo "Trying with fuzz..."
        if git apply --check --ignore-whitespace --reject test.patch; then
            echo "✅ Patch would apply with rejects/fuzz"
        else
            echo "❌ Patch completely incompatible"
        fi
    fi
fi

echo ""
echo "=== 4. ACTUALLY APPLYING PATCH ==="
echo "Applying with verbose output..."
if git apply -v test.patch; then
    echo "✅ Patch applied successfully!"
    
    echo ""
    echo "=== 5. VERIFYING CHANGES ==="
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
    echo "✅ PATCH VALIDATION SUCCESSFUL!"
else
    echo "❌ Patch application failed"
    echo ""
    echo "Git status:"
    git status
    
    echo ""
    echo "Diff of what git sees:"
    git diff
fi

echo ""
echo "=== CLEANUP ==="
echo "Test completed. Cleaning up..."
cd /
rm -rf /tmp/cozystack-patch-test
echo "Done!"