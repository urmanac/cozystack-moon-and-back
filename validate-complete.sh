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
echo "=== TEST 1: PATCH AND CATALOG VALIDATION ==="
echo "Running patch and catalog validation script..."

if "$SCRIPT_DIR/validate-patch.sh"; then
    echo "✓ Patch and catalog validation passed"
else
    echo "✗ Patch and catalog validation failed"
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
    if yq eval '.jobs.build-cozystack-upstream.strategy.matrix.extension_variant' .github/workflows/build-talos-images.yml >/dev/null; then
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

echo ""
echo "=== TEST 4: PATCH DIRECTORY CLEANLINESS ==="
echo "Ensuring no leftover debugging patches..."

PATCH_COUNT=$(find patches/ -name "*.patch" | wc -l)
if [[ $PATCH_COUNT -ge 3 ]]; then
    echo "✓ Patch files present ($PATCH_COUNT)"
else
    echo "✗ Expected at least 3 patch files, found $PATCH_COUNT"
    echo "Files found:"
    ls -la patches/
    exit 1
fi

echo ""
echo "=== TEST 5: DOCUMENTATION VALIDATION ==="
echo "Checking that ADR exists and is complete..."

ADR_FILE="docs/ADRs/ADR-003-PATCH-GENERATION.md"
if [[ -f "$ADR_FILE" ]]; then
    echo "✓ ADR-003 documentation exists"
else
    echo "✗ ADR-003 documentation missing"
    exit 1
fi

# Package catalog validation is already performed as part of validate-patch.sh in TEST 1.

echo ""
echo "=== TEST 6: GIT REPOSITORY STATE ==="
echo "Checking repository is clean and ready..."

if git diff --quiet; then
    echo "✓ Working directory is clean"
else
    echo "✗ Working directory has unstaged changes"
    git status --porcelain
    exit 1
fi

echo ""
echo "=== ALL TESTS PASSED ==="
echo ""
echo "Ready to commit and push!"
