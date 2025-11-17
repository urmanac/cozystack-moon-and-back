# ADR-002: Test-Driven Generation (TDG) Methodology 

**Date:** 2025-11-16  
**Status:** Accepted  
**Context:** Infrastructure Development for CozyStack ARM64 Implementation  
**Related:** [ADR-003: Patch Generation Best Practices](ADR-003-PATCH-GENERATION.md)

## Summary

Adopt Test-Driven Generation (TDG) methodology for infrastructure development, replacing traditional trial-and-error approaches with systematic validation and generation patterns.

## Problem

**Traditional Infrastructure Development Anti-Patterns:**

```
❌ Classic Approach:
1. Write code/config → 2. Push to CI → 3. Debug failures → 4. Repeat 15+ times
5. Eventually works → 6. No confidence in why → 7. Fear of changes
```

**Evidence from Our Project:**
- **15+ failed commits** with manual patch generation attempts
- **Hours of CI debugging cycles** for "patch fragment without header" errors  
- **Stream of half-working fixes** without understanding root causes
- **Knowledge not transferable** to future maintainers

**Impact:**
- Slow development velocity
- CI system abuse (expensive compute cycles)
- Technical debt accumulation
- Knowledge gaps for team members

## Decision

**✅ CHOSEN: Test-Driven Generation (TDG) Methodology**

**Core Principles:**

### 1. **Local Validation First**
```bash
# BEFORE pushing to CI
./validate-complete.sh  # 6-stage local validation
```

**Validation Stages:**
1. **Upstream Integration**: Patch applies cleanly to target repository
2. **Content Verification**: All expected changes present in result
3. **Workflow Syntax**: GitHub Actions YAML validates locally  
4. **Dependencies**: Required tools available and functional
5. **Cleanliness**: No debugging artifacts or temporary files
6. **Documentation**: Changes documented and knowledge captured

### 2. **Generation Over Manual Construction**
```bash
# ✅ GENERATE patches with Git tools
git diff > patch-file.patch

# ❌ MANUAL string manipulation 
echo "diff --git a/file.txt b/file.txt" > patch-file.patch
```

### 3. **Systematic Problem Solving**
```
🔍 Understand → 🧪 Test → ✅ Validate → 🚀 Generate → 📚 Document
```

### 4. **Knowledge Transfer Through Documentation**
- Architecture Decision Records (ADRs) for key decisions
- Comprehensive validation suites prevent regressions
- Explicit documentation of "why" not just "what"

## Implementation

**Before TDG (Chaos):**
```
Manual patches → CI failure → Debug → Guess → Repeat
```

**After TDG (Systematic):**
```
Local validation → Understanding → Clean solution → CI success
```

**Concrete Example from Our Project:**

**Problem**: Patch generation failures
**TDG Approach:**
1. **Understand**: Manual patches lack proper Git headers
2. **Test**: Use `git apply --check` for validation  
3. **Generate**: Use `git diff` for proper patch creation
4. **Document**: ADR-003 captures knowledge for future use

**Result**: 3 clean, working commits instead of 15+ failures

## Tools & Infrastructure

**Validation Suite (`validate-complete.sh`):**
- Prevents "works on my machine" syndrome
- Catches integration issues before CI
- Provides fast feedback loop (seconds vs. minutes)

**Documentation Standards:**
- ADRs for architectural decisions
- Comprehensive README with clear goals
- Validation procedures documented and executable

**CI as Final Validation:**
- Not primary development tool
- Validates integration with real infrastructure  
- Prevents regressions in production environment

## Alternatives Considered

**❌ Traditional Trial-and-Error:**
- Pros: "Just code and push" simplicity
- Cons: Wastes CI resources, slow feedback, knowledge gaps
- Rejected: Demonstrated inefficiency in our project

**❌ Pure TDD (Test-Driven Development):**
- Pros: Excellent for application code
- Cons: Infrastructure has different testing challenges
- Rejected: TDG better fits infrastructure patterns

**❌ "YOLO" Development:**
- Pros: Fast initial feeling
- Cons: Technical debt explosion, maintenance nightmare
- Rejected: Unsustainable for production systems

## Metrics & Validation

**Success Metrics (Observed):**

| Metric | Before TDG | After TDG | Improvement |
|--------|------------|-----------|-------------|
| Failed commits | 15+ | 3 | 80% reduction |
| CI debugging time | Hours | Minutes | 90% reduction |
| Knowledge capture | Minimal | Comprehensive | Qualitative jump |
| Confidence level | Low | High | Maintainable |

**Validation Criteria:**
- ✅ Local validation prevents CI failures
- ✅ Solutions are reusable and documented
- ✅ Team members can understand and modify code
- ✅ Regression detection through automation

## Consequences

**Positive:**
- ✅ **Faster development velocity** after initial learning curve
- ✅ **Higher quality solutions** through systematic approach  
- ✅ **Knowledge transfer** through comprehensive documentation
- ✅ **Maintainable systems** with clear decision history
- ✅ **Confidence in changes** through validation coverage

**Negative:**
- ⚠️ **Initial overhead** of setting up validation suites
- ⚠️ **Discipline required** to follow methodology consistently
- ⚠️ **Documentation maintenance** adds ongoing effort

**Neutral:**
- 🔄 **Cultural shift** from "move fast and break things" to "move fast with confidence"
- 🔄 **Tool investment** in local validation infrastructure

## Future Applications

**TDG Pattern for Infrastructure:**
1. **Cloud provisioning**: Terraform plans with validation
2. **Configuration management**: Ansible playbooks with dry-run
3. **Container builds**: Multi-stage validation before registry push
4. **Security policies**: Policy-as-code with compliance testing

**Knowledge Scaling:**
- ADR template for future decisions
- Validation suite patterns for new projects
- TDG methodology training for team members

---

**Previous ADR:** [ADR-001: ARM64 Architecture Choice](ADR-001-ARM64-ARCHITECTURE.md)  
**Next ADR:** [ADR-003: Patch Generation Best Practices](ADR-003-PATCH-GENERATION.md)

## References

- [Original TDG Article by Chanwit](https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502)
- [Our TDG Success Story](../TDG-PLAN.md)
- [Validation Suite Implementation](../../validate-complete.sh)