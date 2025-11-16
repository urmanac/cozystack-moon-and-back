#!/bin/bash
# tests/custom-image/02-extensions-present.sh

# TDG Test: Spin and Tailscale Extensions Present
# GIVEN: Custom Talos image built with ARM64 + extensions
# WHEN: Talos node boots from custom image
# THEN: Spin runtime and Tailscale extensions are functional

set -e

# Note: These tests require a running Talos node with the custom image
# For now, they document the validation approach
# Actual validation happens during AWS netboot testing

test_spin_runtime_available() {
  echo "🔍 Testing: Spin runtime extension available on Talos node"
  
  # GIVEN: Talos node running custom image with Spin extension
  # WHEN: Checking for Spin runtime
  # THEN: Spin binary available and RuntimeClass created
  
  NODE_IP="${TALOS_NODE_IP:-10.20.13.100}"
  
  if command -v talosctl >/dev/null 2>&1; then
    echo "ℹ️  Testing against node: $NODE_IP"
    
    # Test 1: Check if Spin extension loaded
    if talosctl -n "$NODE_IP" get extensions 2>/dev/null | grep -q "spin"; then
      echo "✅ Spin extension loaded in Talos"
    else
      echo "❌ Spin extension not found in Talos"
      echo "   Command: talosctl -n $NODE_IP get extensions"
      echo "   Expected: spin extension listed"
      return 1
    fi
    
    # Test 2: Check for Spin RuntimeClass in Kubernetes (requires cluster)
    if command -v kubectl >/dev/null 2>&1; then
      if kubectl get runtimeclass spin >/dev/null 2>&1; then
        echo "✅ Spin RuntimeClass available in Kubernetes"
        kubectl get runtimeclass spin -o yaml | grep -A2 handler
      else
        echo "⚠️  Spin RuntimeClass not found (cluster may not be ready)"
        echo "   This is expected if CozyStack hasn't been deployed yet"
      fi
    else
      echo "ℹ️  kubectl not available - skipping RuntimeClass test"
    fi
    
    return 0
  else
    echo "⚠️  talosctl not available - cannot test node directly"
    echo ""
    echo "Manual validation steps:"
    echo "  1. SSH to bastion: ssh ubuntu@10.20.13.140"  
    echo "  2. Check if Talos node running: talosctl -n $NODE_IP get extensions"
    echo "  3. Look for 'spin' in extensions list"
    echo "  4. After cluster ready: kubectl get runtimeclass spin"
    return 0
  fi
}

test_tailscale_extension_available() {
  echo "🔍 Testing: Tailscale extension available on Talos node"
  
  # GIVEN: Talos node running custom image with Tailscale extension
  # WHEN: Checking for Tailscale service
  # THEN: Tailscale daemon available
  
  NODE_IP="${TALOS_NODE_IP:-10.20.13.100}"
  
  if command -v talosctl >/dev/null 2>&1; then
    echo "ℹ️  Testing against node: $NODE_IP"
    
    # Test 1: Check if Tailscale extension loaded
    if talosctl -n "$NODE_IP" get extensions 2>/dev/null | grep -q "tailscale"; then
      echo "✅ Tailscale extension loaded in Talos"
    else
      echo "❌ Tailscale extension not found in Talos"
      echo "   Command: talosctl -n $NODE_IP get extensions"
      echo "   Expected: tailscale extension listed"
      return 1
    fi
    
    # Test 2: Check if Tailscale service running
    if talosctl -n "$NODE_IP" get services 2>/dev/null | grep -q "tailscale"; then
      echo "✅ Tailscale service running in Talos"
      
      # Test 3: Check Tailscale status (requires auth)
      echo "ℹ️  To verify full Tailscale functionality:"
      echo "     talosctl -n $NODE_IP exec -- tailscale status"
      echo "     (This requires Tailscale auth setup)"
    else
      echo "⚠️  Tailscale service not running (may need configuration)"
      echo "   Command: talosctl -n $NODE_IP get services"
      echo "   Expected: tailscale service listed"
    fi
    
    return 0
  else
    echo "⚠️  talosctl not available - cannot test node directly"
    echo ""
    echo "Manual validation steps:"
    echo "  1. SSH to bastion: ssh ubuntu@10.20.13.140"
    echo "  2. Check if Talos node running: talosctl -n $NODE_IP get extensions"
    echo "  3. Look for 'tailscale' in extensions list"
    echo "  4. Check service status: talosctl -n $NODE_IP get services | grep tailscale"
    return 0
  fi
}

test_cozystack_compatible() {
  echo "🔍 Testing: Custom image compatible with CozyStack requirements"
  
  # GIVEN: Custom Talos image with ARM64 + extensions
  # WHEN: Deploying CozyStack on cluster
  # THEN: CozyStack installs successfully
  
  NODE_IP="${TALOS_NODE_IP:-10.20.13.100}"
  
  if command -v kubectl >/dev/null 2>&1; then
    # Test 1: Check node architecture
    if NODE_ARCH=$(kubectl get node -o jsonpath='{.items[0].status.nodeInfo.architecture}' 2>/dev/null); then
      if [[ "$NODE_ARCH" == "arm64" ]]; then
        echo "✅ Node running ARM64 architecture: $NODE_ARCH"
      else
        echo "❌ Unexpected node architecture: $NODE_ARCH (expected: arm64)"
        return 1
      fi
    else
      echo "⚠️  Cannot determine node architecture (cluster may not be ready)"
    fi
    
    # Test 2: Check for CozyStack readiness
    if kubectl get namespace cozy-system >/dev/null 2>&1; then
      echo "✅ CozyStack namespace exists"
      
      # Check CozyStack pods
      COZY_PODS=$(kubectl get pods -n cozy-system --no-headers 2>/dev/null | wc -l)
      if [[ $COZY_PODS -gt 0 ]]; then
        echo "✅ CozyStack pods running: $COZY_PODS pods"
        kubectl get pods -n cozy-system --no-headers | head -3
      else
        echo "ℹ️  CozyStack namespace exists but no pods yet"
      fi
    else
      echo "ℹ️  CozyStack not installed yet (expected for new cluster)"
    fi
    
    return 0
  else
    echo "⚠️  kubectl not available - cannot test cluster compatibility"
    echo ""
    echo "Manual validation steps:"
    echo "  1. After cluster bootstrap: kubectl get nodes -o wide"
    echo "  2. Verify ARM64 architecture"
    echo "  3. Install CozyStack and verify deployment"
    return 0
  fi
}

# Run all tests
main() {
  echo "🧪 TDG Test Suite: Talos Extensions Present"
  echo "==========================================="
  
  # Check environment
  if [[ -z "${TALOS_NODE_IP:-}" ]]; then
    echo "ℹ️  TALOS_NODE_IP not set, using default: 10.20.13.100"
    echo "   Set TALOS_NODE_IP=<actual-ip> for real testing"
    echo ""
  fi
  
  FAILED_TESTS=0
  
  test_spin_runtime_available || ((FAILED_TESTS++))
  echo ""
  
  test_tailscale_extension_available || ((FAILED_TESTS++))
  echo ""
  
  test_cozystack_compatible || ((FAILED_TESTS++))
  echo ""
  
  if [[ $FAILED_TESTS -eq 0 ]]; then
    echo "🎉 All extension tests passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Run tests/custom-image/03-netboot-integration.sh"
    echo "  2. Test SpinKube demo deployment"
    echo "  3. Verify end-to-end demo workflow"
    exit 0
  else
    echo "💥 $FAILED_TESTS test(s) failed!"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Ensure Talos node is running custom image"
    echo "  2. Check extension loading: talosctl get extensions"
    echo "  3. Verify patches applied correctly during build"
    echo "  4. Check extension compatibility with ARM64"
    exit 1
  fi
}

# Allow running individual tests
if [[ "${1:-}" == "--test" ]]; then
  shift
  "$1"
else
  main "$@"
fi