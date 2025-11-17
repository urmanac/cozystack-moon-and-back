# ADR-001: ARM64 Architecture Choice for CozyStack Deployment

**Date:** 2025-11-16  
**Status:** Accepted  
**Context:** CozySummit Virtual 2025 Demo Architecture  

## Summary

Choose ARM64 as the target architecture for CozyStack deployment instead of the default AMD64, enabling validation on AWS t4g instances before committing to Raspberry Pi hardware purchases.

## Problem

**Traditional Home Lab Approach:**
- Buy expensive hardware first, discover limitations later
- AMD64 hardware runs hot (76°F office space heater problem)
- Higher power consumption and cooling costs
- Limited ability to test ARM64 workloads like SpinKube

**Business Context:**
- CozySummit Virtual 2025 demo on December 4, 2025
- Need to demonstrate ARM64 CozyStack capabilities
- Budget constraints: <$0.10/month baseline, <$15/month validation
- Risk of buying wrong hardware for home lab requirements

## Decision

**✅ CHOSEN: ARM64-First Architecture**

**Target Platforms:**
1. **AWS t4g instances** (ARM64 Graviton) for cloud validation
2. **Raspberry Pi CM4/CM3** for eventual home lab deployment  
3. **Future ARM64 hardware** with lower power consumption

**Key Benefits:**
- **Cost Validation**: Test before buying hardware (~$400-800 savings)
- **Performance Testing**: Validate ARM64 workloads in production-like environment
- **Power Efficiency**: ARM64 typically 40-60% more power efficient than x86
- **Real-world Testing**: AWS t4g provides actual ARM64 performance data
- **SpinKube Compatibility**: WebAssembly runs efficiently on ARM64

## Alternatives Considered

**❌ Traditional AMD64 Approach:**
- Pros: Default CozyStack support, familiar tooling
- Cons: Higher power consumption, missed ARM64 opportunity
- Rejected: Doesn't solve the "office space heater" problem

**❌ Buy Hardware First:**
- Pros: Immediate home lab satisfaction
- Cons: Risk of wrong hardware choice, no cloud validation
- Rejected: Violates "smart validation" principle

**❌ Hybrid Approach (AMD64 + ARM64):**
- Pros: Best of both worlds  
- Cons: Doubles complexity and maintenance
- Rejected: Limited development time for demo

## Implementation

**Immediate (CozySummit Demo):**
- Custom ARM64 Talos images with Spin + Tailscale extensions
- AWS t4g.nano validation infrastructure (<$15/month)
- Automated netboot via Matchbox server

**Future (Home Lab):**
- Raspberry Pi CM4-based nodes using validated images
- Power-efficient ARM64 home lab design
- Same Talos images, different hardware platform

## Metrics & Validation

**Success Criteria:**
- [ ] ARM64 Talos images build successfully
- [ ] SpinKube workloads run on ARM64  
- [ ] Power consumption measurements vs. AMD64
- [ ] Performance benchmarks on t4g instances
- [ ] Cost analysis for home lab transition

**Decision Review:**
- **January 2025**: Post-demo analysis of ARM64 performance
- **March 2025**: Home lab hardware purchase decision based on data

## Consequences

**Positive:**
- ✅ Validates architecture before hardware investment
- ✅ Demonstrates cutting-edge ARM64 CozyStack deployment
- ✅ Reduces long-term power and cooling costs
- ✅ Aligns with industry trends (Apple Silicon, AWS Graviton)

**Negative:**
- ⚠️ Requires custom Talos image builds (upstream is AMD64-first)
- ⚠️ Some debugging/tooling may be AMD64-specific
- ⚠️ Learning curve for ARM64-specific optimizations

**Neutral:**
- 🔄 Documentation and knowledge transfer requirements
- 🔄 Additional testing surface area for compatibility

---

**Next ADR:** [ADR-002: Test-Driven Generation Methodology](ADR-002-TDG-METHODOLOGY.md)