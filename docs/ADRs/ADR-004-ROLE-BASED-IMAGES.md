# ADR-004: Role-Based Talos Image Architecture

**Date:** 2025-11-18  
**Status:** Accepted  
**Context:** CozyStack ARM64 Cluster Formation Requirements  
**Related:** [ADR-001: ARM64 Architecture Choice](ADR-001-ARM64-ARCHITECTURE.md), [ADR-002: TDG Methodology](ADR-002-TDG-METHODOLOGY.md)

## Summary

Implement role-based Talos image architecture with separate compute and gateway node variants to enable proper Kubernetes cluster formation with Tailscale subnet routing.

## Problem

**Single Image with All Extensions Breaks Cluster Formation:**

```diff
Current Implementation:
-EXTENSIONS="drbd zfs"
+EXTENSIONS="drbd zfs spin tailscale"
```

**Critical Issue:** Kubernetes nodes only reach "Ready" state when ALL configured Talos extensions are active and properly configured. With Tailscale extension on every node:

1. **Multiple Subnet Routers**: Every node tries to configure as Tailscale subnet router
2. **Configuration Conflicts**: Multiple nodes compete for same routing role
3. **Cluster Formation Failure**: Nodes hang waiting for conflicting Tailscale configurations
4. **Ready State Never Achieved**: Cluster never becomes operational

## Architecture Requirements

**CozyStack + Tailscale Integration Pattern:**
- **One subnet router per cluster**: Exposes service/pod CIDR to external Tailscale network
- **Multiple compute nodes**: Run WebAssembly workloads without networking conflicts
- **Clean role separation**: Different node types have different extension requirements

**Node Ready Condition Constraint:**
- Nodes wait for ALL configured extensions to become active
- Failed extension configuration = node never reaches Ready state
- Heterogeneous extension sets = different node readiness requirements

## Decision

**✅ CHOSEN: Role-Based Image Architecture**

### 1. **Compute Node Images** (`*-compute`)
```bash
EXTENSIONS="drbd zfs spin"
```

**Purpose:** WebAssembly workload execution
- **Quantity:** Majority of cluster nodes (scalable)
- **Extensions:** Only Spin WebAssembly runtime
- **Ready Condition:** Simple - waits only for Spin activation
- **Network Role:** Standard Kubernetes pod networking

### 2. **Gateway Node Images** (`*-gateway`)
```bash
EXTENSIONS="drbd zfs spin tailscale"
```

**Purpose:** Subnet routing + WebAssembly execution
- **Quantity:** Exactly one per cluster
- **Extensions:** Spin runtime + Tailscale subnet router
- **Ready Condition:** Complex - waits for both Spin + Tailscale activation
- **Network Role:** Tailscale subnet router for external access

## Implementation Strategy

### Matrix Build Strategy
```yaml
strategy:
  matrix:
    variant:
      - name: compute
        extensions: "drbd zfs spin"
        suffix: "-compute"
        role: "WebAssembly workload nodes"
      - name: gateway
        extensions: "drbd zfs spin tailscale"  
        suffix: "-gateway"
        role: "Subnet router + compute node"
```

### Patch Generation
- **Option A**: Separate patches per variant
- **Option B**: Parameterized single patch with extension matrix
- **Chosen**: Matrix strategy with single parameterized patch

## Architecture Benefits

### 1. **Cluster Formation Reliability**
- Compute nodes reach Ready state quickly (no Tailscale wait)
- Gateway node handles complex networking configuration independently
- No extension conflicts between node roles

### 2. **Operational Clarity** 
- Clear node role designation at image selection time
- Simplified troubleshooting (role-specific extension issues)
- Predictable cluster behavior patterns

### 3. **Scalability**
- Add compute nodes without network configuration complexity
- Gateway node remains singleton (as required by Tailscale architecture)
- WebAssembly workloads can scale across all nodes

### 4. **CozyStack Learning Demonstration**
- Shows CozyStack build machinery flexibility
- Demonstrates Talos Linux customization patterns
- Provides template for other specialized node roles

## Alternatives Considered

**❌ Single Image with Conditional Extension Loading:**
- Pros: Simpler build process
- Cons: Runtime complexity, configuration management issues
- Rejected: Violates "extensions always active" Talos principle

**❌ Configuration-Time Extension Selection:**
- Pros: Maximum flexibility
- Cons: Complex orchestration, error-prone deployment
- Rejected: Increases operational complexity

**❌ Post-Boot Extension Management:**
- Pros: Dynamic role assignment
- Cons: Not supported by Talos architecture, fragile
- Rejected: Architectural incompatibility

## Validation Strategy

### TDG Test Requirements
```bash
tests/cluster-formation/
├── 01-compute-only-cluster.sh    # Multiple compute nodes form working cluster
├── 02-mixed-role-cluster.sh      # Compute + gateway cluster formation  
├── 03-tailscale-routing-test.sh  # Gateway provides subnet routing
└── 04-extension-isolation.sh     # No extension conflicts between roles
```

## Success Criteria

- [ ] Compute nodes (spin-only) reach Ready state without Tailscale
- [ ] Gateway node (spin+tailscale) joins cluster and provides routing
- [ ] Mixed cluster demonstrates full WebAssembly + networking functionality
- [ ] Clear documentation guides node role selection
- [ ] TDG tests validate all cluster formation scenarios

## Consequences

**Positive:**
- ✅ Reliable cluster formation with predictable node behavior
- ✅ Clear operational model for different node types
- ✅ Demonstrates advanced CozyStack build system usage
- ✅ Scalable architecture for larger cluster deployments

**Negative:**
- ⚠️ Requires image selection decision during node provisioning
- ⚠️ Slightly more complex CI build matrix
- ⚠️ Need clear documentation for role selection guidance

**Neutral:**
- 🔄 Two container images instead of one (manageable complexity)
- 🔄 Additional test coverage for cluster formation scenarios

---

**Previous ADR:** [ADR-003: Patch Generation Best Practices](ADR-003-PATCH-GENERATION.md)  
**Next ADR:** [ADR-005: TBD](ADR-005-TBD.md) *(placeholder)*

**Next Steps:** Implement matrix build strategy in CI workflow, create TDG tests for cluster formation validation, document node role selection guidance.