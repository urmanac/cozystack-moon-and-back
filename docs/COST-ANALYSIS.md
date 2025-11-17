# Cost Analysis: Cloud Validation vs. Home Lab

## Executive Summary

This document provides an honest cost analysis for validating ARM64 CozyStack in AWS before deploying to Raspberry Pi hardware. The goal is to make informed decisions about when cloud makes sense vs. home lab deployment.

## Current Baseline Costs

### Home Lab Reality Check *(Estimates based on typical x86 hardware)*
```
Power consumption (x86 servers):    $30-50/month
Space heating (unintentional):      Wife's sanity = priceless
Equipment depreciation:             ~$100/month (3-year cycle)
---------------------------------------------------------
Total home lab cost:                $130-150/month
```

### AWS Cloud Baseline (No Experiments) *(Source: [AWS Pricing Calculator](https://calculator.aws/), November 2025)*
```
Bastion t4g.small (5 hrs/day):      $0.00 (free tier)
EBS volumes (minimal):              $0.04/month
NAT Gateway (minimal traffic):      $0.04/month  
---------------------------------------------------------
Baseline cost:                      $0.08/month ✅
```

## Validation Phase Costs

### Experiment Sessions (Projected)
```
Session duration:                   2-3 hours
Frequency:                          2-3 sessions/week
Total validation period:            3 weeks (Dec 4 deadline)

Per Session:
- 3x t4g.small nodes:              $0.00 (under free tier limit)
- 4x EBS volumes (8GB):            $0.25-0.50
- NAT Gateway egress:              $0.15-0.35
- Data transfer:                   $0.00 (private networking)
---------------------------------------------------------
Cost per session:                   $0.40-0.85
```

### Validation Budget (3 weeks)
```
Conservative estimate (5 sessions): $2.00-4.25
Aggressive testing (8 sessions):    $3.20-6.80
Safety buffer:                      +50%
---------------------------------------------------------
Total validation budget:            $3.00-10.00
Target ceiling:                     <$15/month ✅
```

## Break-Even Analysis

### When Cloud Makes Sense
1. **Validation phase**: Always cheaper than buying wrong hardware
   - Cost to validate: $3-15 
   - Cost of wrong Raspberry Pi purchase: $500+
   - **ROI**: 3,000-16,000%

2. **Small-scale production**: Under $40/month
   - Competitive with home lab power costs
   - Better SLA and management overhead
   - No space heating issues

3. **Hybrid deployment**: $20-30/month sweet spot
   - Critical services in cloud (DNS, ingress, small workloads)
   - Heavy compute at home (efficient ARM64)
   - Best of both worlds

### When Home Lab Wins
1. **Large-scale compute**: Over $40/month cloud cost
2. **Bulk storage**: EBS becomes expensive vs. local storage
3. **Learning/experimentation**: Unlimited hours without cost concern
4. **Privacy-first workloads**: No external dependencies

## Cost Tracking Implementation

### Required Monitoring
```bash
# Before each experiment
./scripts/cost-snapshot.sh --label "pre-experiment-N"

# After each session  
./scripts/cost-snapshot.sh --label "post-experiment-N"
./scripts/cost-diff.sh pre-experiment-N post-experiment-N

# Weekly summary
./scripts/cost-summary.sh --week N
```

### Success Metrics
- [ ] Baseline cost stays under $0.10/month
- [ ] Validation phase stays under $15/month total  
- [ ] Each experiment session costs less than $1.00
- [ ] Total validation cheaper than wrong hardware purchase
- [ ] Clear recommendation: cloud vs. home for different scales

## Decision Framework

### Use Cloud When:
- Validating before hardware purchase
- Need high SLA for critical services
- Want to avoid home lab heat/noise
- Compute needs are modest (<$40/month)
- Experimenting with architectures (ARM64, etc.)

### Use Home Lab When:
- Heavy compute workloads (>$40/month cloud cost)
- Large storage requirements
- Learning/development (unlimited hours)
- Privacy/air-gapped requirements
- Already have efficient hardware

### Hybrid Approach:
- **Cloud**: DNS, ingress, small services, CI/CD
- **Home**: Heavy compute, storage, bulk workloads
- **Cost target**: $20-30/month cloud + efficient ARM64 home

## Experimental Results (TBD)

*This section will be updated with real cost data as experiments progress.*

### Session 1: Single Node Validation
- Date: TBD
- Duration: TBD  
- Resources: 1x t4g.small + EBS
- Cost: $TBD
- Notes: TBD

### Session 2: Three Node Cluster
- Date: TBD
- Duration: TBD
- Resources: 3x t4g.small + EBS  
- Cost: $TBD
- Notes: TBD

### Final Validation Summary
- Total sessions: TBD
- Total cost: $TBD
- Cost per hour: $TBD
- ROI vs. wrong hardware: TBD%
- **Final recommendation**: TBD

## Recommendations for CozySummit Talk

### Honest Messaging
**Don't say**: "Run production CozyStack for $0.08/month"
**Do say**: "Validate ARM64 before buying hardware for $X, then deploy with confidence"

### Key Points
1. Cloud validation costs less than buying wrong hardware
2. Break-even point: ~$40/month for production workloads
3. Hybrid approach maximizes benefits
4. Real cost data from actual experiments
5. Make informed decisions, not emotional ones

### Demo Script
1. Show baseline: $0.08/month (just infrastructure)
2. Launch experiment: Live cost monitoring
3. Deploy CozyStack: Show real costs accumulating
4. Final tally: "This 30-minute demo cost $0.75"
5. Compare: "Wrong Raspberry Pi purchase: $500+"
6. Conclude: "Now we can buy the RIGHT hardware"

## Appendix: Cost Mitigation Strategies

### If Costs Exceed Budget
1. **Shorter sessions**: 1 hour instead of 2-3
2. **Fewer experiments**: 3 instead of 5
3. **Smaller instances**: t4g.nano for testing  
4. **Home lab fallback**: Demo still works locally
5. **Accept higher cost**: Adjust messaging accordingly

### Optimization Opportunities
1. **Reserved instances**: If committing to longer term
2. **Spot instances**: For non-critical experiments
3. **Storage optimization**: Smaller EBS volumes
4. **Network optimization**: Reduce NAT Gateway usage
5. **Scheduling**: Run during low-cost hours

---

*Last updated: November 16, 2025*
*Next update: After first experiment session*