#!/bin/bash
# tests/run-all-custom-image-tests.sh

# TDG Test Runner for Custom Talos Images
# Runs all custom image validation tests in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "🧪 TDG Test Suite: Custom Talos Images"
echo "======================================"
echo ""

# Test 1: Build Success
echo "▶️  Running Test 1: Build Success"
if "$SCRIPT_DIR/custom-image/01-build-success.sh"; then
    echo "✅ Test 1 PASSED"
    ((PASSED_TESTS++))
else
    echo "❌ Test 1 FAILED"
    ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))
echo ""

# Test 2: Extensions Present (requires running Talos node)
echo "▶️  Running Test 2: Extensions Present"
if [[ -n "${TALOS_NODE_IP:-}" || -n "${SKIP_NODE_TESTS:-}" ]]; then
    if "$SCRIPT_DIR/custom-image/02-extensions-present.sh"; then
        echo "✅ Test 2 PASSED"
        ((PASSED_TESTS++))
    else
        echo "❌ Test 2 FAILED"
        ((FAILED_TESTS++))
    fi
else
    echo "⏸️  Test 2 SKIPPED (no TALOS_NODE_IP set)"
    echo "   Set TALOS_NODE_IP=<node-ip> to run this test"
fi
((TOTAL_TESTS++))
echo ""

# Summary
echo "📊 Test Results Summary"
echo "======================"
echo "Total Tests:  $TOTAL_TESTS"
echo "Passed:       $PASSED_TESTS"
echo "Failed:       $FAILED_TESTS"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "🎉 All tests passed! Custom Talos images are ready."
    echo ""
    echo "Next steps:"
    echo "  1. Pass AWS-INFRASTRUCTURE-HANDOFF.md to AWS-capable Claude agent"
    echo "  2. Deploy infrastructure and test end-to-end netboot"
    echo "  3. Bootstrap CozyStack and deploy SpinKube demo"
    exit 0
else
    echo "💥 $FAILED_TESTS test(s) failed!"
    echo ""
    echo "Check the output above for specific failure details."
    echo "Common issues:"
    echo "  - GitHub Actions build not complete"
    echo "  - GHCR image not accessible"
    echo "  - Extensions not properly patched"
    exit 1
fi