#!/bin/bash
# tests/cost/22-cost-tracking.sh
# Test cost tracking and budget monitoring

set -e

echo "🧮 Testing cost tracking and budget compliance..."

test_baseline_cost_documented() {
  echo "  → Testing baseline cost documentation..."
  
  # GIVEN: Documentation exists for baseline costs
  if [ ! -f "docs/COST-ANALYSIS.md" ]; then
    echo "❌ Missing docs/COST-ANALYSIS.md"
    return 1
  fi
  
  # WHEN: Checking documented baseline
  baseline_documented=$(grep -c "Baseline cost.*0.08" docs/COST-ANALYSIS.md || echo "0")
  
  # THEN: Baseline should be documented as $0.08/month
  if [ "$baseline_documented" -eq 0 ]; then
    echo "❌ Baseline cost not documented"
    return 1
  fi
  
  echo "✅ Baseline cost properly documented"
  return 0
}

test_validation_budget_defined() {
  echo "  → Testing validation budget limits..."
  
  # GIVEN: Budget constraints are defined
  budget_limit=$(grep -c "Target ceiling.*<.*15" docs/COST-ANALYSIS.md || echo "0")
  budget_section=$(grep -c "Validation Budget" docs/COST-ANALYSIS.md || echo "0")
  
  # WHEN: Checking budget documentation  
  # THEN: Should have <$15/month validation target
  if [ "$budget_limit" -eq 0 ] || [ "$budget_section" -eq 0 ]; then
    echo "❌ Validation budget not properly defined"
    return 1
  fi
  
  echo "✅ Validation budget target defined"
  return 0
}

test_session_cost_framework() {
  echo "  → Testing session cost estimation..."
  
  # GIVEN: Cost framework exists
  session_cost=$(grep -c "Cost per session" docs/COST-ANALYSIS.md || echo "0")
  
  # WHEN: Checking session cost estimates
  # THEN: Should have per-session cost estimates
  if [ "$session_cost" -eq 0 ]; then
    echo "❌ Session cost framework missing"
    return 1
  fi
  
  echo "✅ Session cost framework documented"
  return 0
}

test_break_even_analysis() {
  echo "  → Testing break-even analysis..."
  
  # GIVEN: Break-even analysis exists
  break_even=$(grep -c "Break-even Analysis" docs/COST-ANALYSIS.md || echo "0")
  home_lab_cost=$(grep -c "Home lab.*40" docs/COST-ANALYSIS.md || echo "0")
  
  # WHEN: Checking break-even documentation
  # THEN: Should compare cloud vs home lab costs
  if [ "$break_even" -eq 0 ] || [ "$home_lab_cost" -eq 0 ]; then
    echo "❌ Break-even analysis incomplete"
    return 1
  fi
  
  echo "✅ Break-even analysis documented"
  return 0
}

test_cost_tracking_placeholder() {
  echo "  → Testing cost tracking implementation placeholder..."
  
  # GIVEN: Cost tracking implementation section exists
  cost_tracking=$(grep -c "Cost Tracking Implementation" docs/COST-ANALYSIS.md || echo "0")
  
  # WHEN: Checking implementation framework
  # THEN: Should have framework for real cost tracking
  if [ "$cost_tracking" -eq 0 ]; then
    echo "❌ Cost tracking implementation not defined"
    return 1
  fi
  
  echo "✅ Cost tracking framework ready"
  return 0
}

test_realistic_messaging() {
  echo "  → Testing honest cost messaging..."
  
  # GIVEN: README has been updated for realistic expectations
  honest_messaging=$(grep -c "Validating.*before.*hardware" README.md || echo "0")
  validation_budget=$(grep -c "validation.*15" README.md || echo "0")
  
  # WHEN: Checking messaging honesty
  # THEN: Should avoid overselling $0.08 as production cost
  if [ "$honest_messaging" -eq 0 ] || [ "$validation_budget" -eq 0 ]; then
    echo "❌ Messaging still oversells costs"
    return 1
  fi
  
  echo "✅ Honest cost messaging implemented"
  return 0
}

# Run all cost tracking tests
echo "Running cost tracking validation tests..."

test_baseline_cost_documented && \
test_validation_budget_defined && \
test_session_cost_framework && \
test_break_even_analysis && \
test_cost_tracking_placeholder && \
test_realistic_messaging

echo ""
echo "🎯 Cost tracking tests complete!"
echo ""
echo "Key points validated:"
echo "  • Baseline cost: \$0.08/month (no experiments)"
echo "  • Validation budget: <\$15/month target"
echo "  • Break-even: ~\$40/month vs home lab"
echo "  • Honest messaging: Validation, not production costs"
echo ""
echo "Next: Implement real AWS cost tracking for experiments"