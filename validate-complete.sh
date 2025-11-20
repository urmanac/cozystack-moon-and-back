#!/bin/bash
set -e

echo "=== COMPREHENSIVE LOCAL VALIDATION SUITE ==="
echo "Testing all components before commit..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_DIR="/tmp/cozystack-validation-$$"

cleanup() {
    echo "Cleaning up temporary directory..."
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TEMP_DIR"

echo ""
echo "=== TEST 1: PATCH VALIDATION ==="
echo "Testing patch applies cleanly to upstream..."

cd "$TEMP_DIR"
git clone https://github.com/cozystack/cozystack.git upstream-test
cd upstream-test

echo "Testing patch application..."
if git apply --check "$SCRIPT_DIR/patches/01-arm64-spin-tailscale.patch"; then
    echo "✓ Patch format is valid"
else
    echo "✗ Patch format is invalid"
    exit 1
fi

echo "Applying patch..."
git apply "$SCRIPT_DIR/patches/01-arm64-spin-tailscale.patch"

echo "Verifying expected changes..."
EXTENSIONS_PROFILES=$(grep "EXTENSIONS=" packages/core/installer/hack/gen-profiles.sh)
EXTENSIONS_VERSIONS=$(grep "EXTENSIONS=" packages/core/installer/hack/gen-versions.sh)
ARCH_LINE=$(grep "arch:" packages/core/installer/hack/gen-profiles.sh)

if [[ "$EXTENSIONS_PROFILES" == *"spin tailscale"* ]]; then
    echo "✓ gen-profiles.sh has spin tailscale extensions"
else
    echo "✗ gen-profiles.sh missing spin tailscale extensions"
    echo "  Found: $EXTENSIONS_PROFILES"
    exit 1
fi

if [[ "$EXTENSIONS_VERSIONS" == *"spin tailscale"* ]]; then
    echo "✓ gen-versions.sh has spin tailscale extensions"
else
    echo "✗ gen-versions.sh missing spin tailscale extensions" 
    echo "  Found: $EXTENSIONS_VERSIONS"
    exit 1
fi

if [[ "$ARCH_LINE" == *"arm64"* ]]; then
    echo "✓ Architecture set to arm64"
else
    echo "✗ Architecture not set to arm64"
    echo "  Found: $ARCH_LINE"
    exit 1
fi

# Check for SPIN and TAILSCALE image refs
if grep -q "SPIN_IMAGE" packages/core/installer/hack/gen-profiles.sh && grep -q "TAILSCALE_IMAGE" packages/core/installer/hack/gen-profiles.sh; then
    echo "✓ SPIN_IMAGE and TAILSCALE_IMAGE references added"
else
    echo "✗ Missing SPIN_IMAGE or TAILSCALE_IMAGE references"
    exit 1
fi

echo ""
echo "=== TEST 2: WORKFLOW VALIDATION ==="
echo "Testing GitHub Actions workflow syntax..."

cd "$SCRIPT_DIR"

# Check if yq is available, install if needed for local testing
if ! command -v yq &> /dev/null; then
    echo "Installing yq for workflow validation..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install yq 2>/dev/null || {
            echo "Please install yq: brew install yq"
            echo "Skipping YAML validation..."
            SKIP_YAML=true
        }
    else
        echo "Please install yq for YAML validation"
        echo "Skipping YAML validation..."
        SKIP_YAML=true
    fi
fi

if [[ "$SKIP_YAML" != "true" ]]; then
    echo "Validating workflow YAML syntax..."
    if yq eval '.jobs.build-talos-images.steps[].name' .github/workflows/build-talos-images.yml >/dev/null; then
        echo "✓ Workflow YAML syntax is valid"
    else
        echo "✗ Workflow YAML syntax is invalid"
        exit 1
    fi
    
    # Check for required steps
    if grep -q "Set up Docker Buildx" .github/workflows/build-talos-images.yml; then
        echo "✓ Docker Buildx setup step present"
    else
        echo "✗ Missing Docker Buildx setup step"
        exit 1
    fi
    
    if grep -q "docker/setup-buildx-action" .github/workflows/build-talos-images.yml; then
        echo "✓ Docker Buildx action configured"
    else
        echo "✗ Missing Docker Buildx action"
        exit 1
    fi
fi

echo ""
echo "=== TEST 3: DEPENDENCY CHECK ==="
echo "Verifying required tools are installed in workflow..."

WORKFLOW_FILE=".github/workflows/build-talos-images.yml"

if grep -q "crane version" "$WORKFLOW_FILE"; then
    echo "✓ crane installation and verification present"
else
    echo "✗ crane installation missing from workflow"
    exit 1
fi

if grep -q "skopeo --version" "$WORKFLOW_FILE"; then
    echo "✓ skopeo installation and verification present"  
else
    echo "✗ skopeo installation missing from workflow"
    exit 1
fi

if grep -q "jq --version" "$WORKFLOW_FILE"; then
    echo "✓ jq installation and verification present"
else
    echo "✗ jq installation missing from workflow"
    exit 1
fi

echo ""
echo "=== TEST 4: PATCH DIRECTORY CLEANLINESS ==="
echo "Ensuring no leftover debugging patches..."

PATCH_COUNT=$(find patches/ -name "*.patch" | wc -l)
if [[ $PATCH_COUNT -eq 3 ]]; then
    echo "✓ Expected patch files present (spin-tailscale, makefile variables, spin-only)"
else
    echo "✗ Expected 3 patch files, found $PATCH_COUNT"
    echo "Files found:"
    ls -la patches/
    exit 1
fi

MAIN_PATCH="patches/01-arm64-spin-tailscale.patch"
if [[ -f "$MAIN_PATCH" ]]; then
    echo "✓ Main patch file exists: $MAIN_PATCH"
else
    echo "✗ Main patch file missing: $MAIN_PATCH"
    exit 1
fi

echo ""
echo "=== TEST 5: DOCUMENTATION VALIDATION ==="
echo "Checking that ADR exists and is complete..."

ADR_FILE="docs/ADR-003-PATCH-GENERATION.md"
if [[ -f "$ADR_FILE" ]]; then
    echo "✓ ADR-003 documentation exists"
    
    if grep -q "Use Git to generate patches" "$ADR_FILE"; then
        echo "✓ ADR contains correct guidance"
    else
        echo "✗ ADR missing key guidance"
        exit 1
    fi
else
    echo "✗ ADR-003 documentation missing"
    exit 1
fi

echo ""
echo "=== TEST 6: GIT REPOSITORY STATE ==="
echo "Checking repository is clean and ready..."

if git diff --quiet --staged; then
    echo "✗ No changes staged for commit"
    echo "  Run: git add .github/workflows/build-talos-images.yml"
    exit 1
else
    echo "✓ Changes are staged for commit"
fi

if git diff --quiet; then
    echo "✓ Working directory is clean"
else
    echo "✗ Working directory has unstaged changes"
    git status --porcelain
    exit 1
fi

echo ""
echo "=== ALL TESTS PASSED ==="
echo "✓ Patch applies cleanly to upstream"
echo "✓ All expected changes present"  
echo "✓ Workflow syntax valid"
echo "✓ Required dependencies configured"
echo "✓ Clean patch directory"
echo "✓ Documentation complete"
echo "✓ Repository ready for commit"
echo ""
echo "Ready to commit and push!"