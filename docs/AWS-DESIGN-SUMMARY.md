---
title: "Design"
layout: default
---

# AWS Infrastructure Design (Claude Desktop Analysis)

**Status**: ✅ **APPROVED DESIGN** - Ready for implementation  
**Source**: Claude Desktop comprehensive analysis (DESKTOP.md)  
**Target**: December 3, 2025 CozySummit demo

## Executive Summary

Deploy 3-node ARM64 Talos cluster using **boot-to-talos** to install our existing OCI images on EC2 instances. This eliminates AMI management while maintaining parity with home lab builds.

## Key Architecture Decisions

### ✅ Use boot-to-talos (NOT traditional PXE)
**Problem**: EC2 doesn't support PXE netboot  
**Solution**: boot-to-talos installs from our existing OCI images  
**Benefit**: Same images work in home lab + cloud, no AMI management

### ✅ Single Public Subnet Design  
**CIDR**: `10.10.0.0/16` VPC, `10.10.0.0/24` public subnet  
**Rationale**: Layer 2 adjacency for MetalLB ARP, simpler than multi-subnet  
**Security**: No public IPs on Talos nodes, IPv6 for bastion SSH only

### ✅ Static ENI for Bastion
**IP**: `10.10.0.100` (Elastic Network Interface)  
**Benefit**: Survives ASG replacements, enables IP forwarding for NAT  
**Cost**: Free (primary ENI)

### ✅ No NAT Gateway
**IPv6**: Bastion uses IPv6 for SSH access  
**IPv4 NAT**: Wireguard tunnel to university for IPv4 when needed  
**Savings**: ~$30+/month avoided

## Infrastructure Layout

```
VPC: 10.10.0.0/16 (sandbox-eu-vpc)
└── Public Subnet: 10.10.0.0/24
    ├── Bastion: 10.10.0.100 (ENI + IPv6)
    ├── Talos Gateway: 10.10.0.101 (t4g.medium)
    ├── Talos Compute 2: 10.10.0.102 (t4g.medium)  
    └── Talos Compute 3: 10.10.0.103 (t4g.medium)
```

## Node Configuration

**OCI Images** (published in GHCR):
- Gateway: `ghcr.io/urmanac/talos-cozystack-spin-tailscale/talos:latest`
- Compute: `ghcr.io/urmanac/talos-cozystack-spin-only/talos:latest`

**Instance Types**: t4g.medium (4 vCPU, 8GB RAM)  
**Storage**: 50GB gp3 encrypted EBS per node  
**Networking**: Static IPs via kernel args (no DHCP after install)

## Implementation Status

**Ready for Stakpak Agent** ✅
- Design approved and documented
- OCI images available in GHCR  
- Cost estimates validated (~$16-20/month)
- TDG tests updated to match architecture

**Next Steps**:
1. Stakpak agent implements Terraform in `urmanac/aws-accounts`
2. Test boot-to-talos workflow on single node
3. Scale to full 3-node cluster
4. Validate CozyStack installation

## Cost Analysis

**Monthly** (5 hrs/day, 30 days):
- 4x t4g instances: 600 hrs (under 750 hr free tier) = ~$0
- 4x 50GB EBS gp3: $16.00/month  
- ENI: Free
- **Total: ~$16-20/month**

**Demo Week** (full-time Dec 1-4): ~$40-50

**References**:
- Full design: [DESKTOP.md](../DESKTOP.md)
- TDG tests: [TDG-PLAN.md](TDG-PLAN.md)  
- ADR-004: [Role-Based Images](ADRs/ADR-004-ROLE-BASED-IMAGES.html)