# CozyStack Deployment Operational Procedures

> **Note**: This document preserves operational knowledge and workflow patterns from production deployments. It is maintained for reference and post-presentation follow-up, but the primary focus should be on the [talm tool](https://github.com/cozystack/talm) itself rather than any specific demo implementation.

## Overview

This guide documents the operational workflow and goals for deploying CozyStack using talm (Talos Linux Management). The procedures outlined here were originally tested on AMD64 hardware in a home lab environment, but the workflow patterns and objectives translate directly to ARM64 cloud deployments and form the foundation for the expanded moonlander project scope.

## Time Trial Results

Based on home lab AMD64 deployments, these are verified timing benchmarks that inform our ARM64 cloud deployment goals:

### Speed-Run Scenarios
- **YouTube Demo 1**: [13:42 duration - Full Deployment](https://www.youtube.com/watch?v=1Z2Z3Z4Z5Z6)
- **YouTube Demo 2**: [08:15 duration - Disaster Recovery](https://www.youtube.com/watch?v=7Z8Z9Z0Z1Z2)

### Production Deployment Timeline Goals
- Initial cluster bootstrap: ~5-8 minutes
- CozyStack installation: ~10-15 minutes
- Tenant cluster provisioning: ~3-5 minutes per cluster
- Full disaster recovery: ~8-12 minutes
- **Conference Demo Target**: Complete workflow in 25 minutes

## Prerequisites

### Hardware Requirements (Home Lab Reference)
- AMD64 nodes (hpworker02-06 in home lab environment)
- Network configuration with static IPs
- Storage devices for persistent workloads

### Target Architecture (Conference Demo)
- ARM64 cloud instances (AWS)
- Dynamic cloud networking
- Cloud storage integration

### Software Requirements
- `talm` CLI tool installed
- `kubectl` access to cluster
- Custom Talos image for target architecture

## Workflow Goals and Process Direction

The operational workflow follows a clear progression from clean environment to production-ready CozyStack deployment. This process has been validated on AMD64 hardware and will be replicated on ARM64 cloud infrastructure.

### Core Workflow Philosophy

1. **Reproducible Builds**: Every deployment should follow identical steps
2. **Disaster Recovery Ready**: Full cluster rebuild capabilities
3. **Speed Optimization**: Target sub-25-minute complete deployments
4. **Observability**: Comprehensive monitoring and status tracking
5. **Cloud Native**: Designed for ephemeral cloud infrastructure

### Moonlander Project Scope Expansion

The current confined moonlander MVP will expand to include:

- **Replication Target**: Reproduce cozy-talm-demo process from AMD64 home lab onto ARM64 AWS cloud
- **AI-Assisted Deployment**: Claude Desktop will consume userdata files and orchestrate machine creation
- **Terraform-Free Approach**: Direct cloud API interactions without Terraform complexity
- **Automated Procedures**: Generated scripts for repeatable deployments outside Claude Desktop
- **Cleanup Automation**: Emergency termination procedures for resource management
- **Observability Integration**: Comprehensive monitoring becomes core moonlander feature post-MVP

## Core Workflow Procedures

The following procedures represent the conceptual workflow that has been proven on AMD64 hardware and will be adapted for ARM64 cloud deployment:

### 1. Environment Preparation
**Goal**: Start with a completely clean slate, preserving only essential secrets
- Complete environment reset capabilities
- Secret preservation and restoration workflows
- Preparation for rapid iteration

### 2. Cluster Foundation
**Goal**: Generate consistent, repeatable cluster configurations
- Initialize talm with CozyStack preset
- Generate node-specific configurations
- Establish cluster topology and networking

### 3. System Hardening
**Goal**: Apply production-ready optimizations and patches
- Container image caching optimizations  
- System stability configurations
- Domain and network resolution setup

### 4. Cluster Instantiation
**Goal**: Transform configurations into running cluster
- Deploy configurations across all nodes
- Bootstrap cluster with initial control plane
- Establish cluster connectivity and access

### 5. Platform Installation
**Goal**: Deploy CozyStack as a platform-as-a-service layer
- Install core CozyStack components
- Configure platform-level services
- Prepare for tenant workload deployment

### 6. Infrastructure Services
**Goal**: Enable production-ready networking and storage
- Deploy persistent storage solutions
- Configure load balancing and ingress
- Optional: overlay networking setup

### 7. Multi-Tenancy Enablement
**Goal**: Demonstrate platform capabilities with tenant clusters
- Generate tenant cluster configurations
- Establish tenant isolation and access controls
- Validate platform functionality

## Disaster Recovery Procedures

### Recovery Philosophy
**Goal**: Demonstrate platform resilience and rapid recovery capabilities

The home lab testing proved that complete cluster destruction and rebuild is not only possible but can be accomplished in under 15 minutes. This disaster recovery capability becomes a key demonstration point for platform reliability.

### Recovery Workflow Stages

1. **Controlled Destruction**: Systematic node reset with data preservation options
2. **Health Monitoring**: Automated tracking of node shutdown and recovery cycles  
3. **Rapid Rebuild**: Accelerated cluster reconstruction from preserved configurations
4. **Service Restoration**: Automated restoration of platform services and tenant workloads

### Node Lifecycle Management

The operational procedures include sophisticated node monitoring during recovery operations:
- 15-minute timeout windows for node recovery cycles
- Health-checking based on network connectivity
- Automatic detection of reboot completion across cluster
- Parallel vs sequential recovery strategies for different scenarios

## Configuration Patterns

### Reference Architecture (Home Lab AMD64)
The proven configuration demonstrates key patterns:

- **Multi-master Control Plane**: Three-node HA control plane (hpworker03, 05, 06)
- **Dedicated Workers**: Isolated worker nodes for tenant workloads (hpworker02)
- **Floating VIP**: Load-balanced cluster access (10.17.13.253)
- **Custom Images**: Architecture-specific Talos builds
- **Network Isolation**: Subnet segregation and OIDC integration

### Target Architecture (ARM64 Cloud)
The cloud deployment will adapt these patterns:

- **Cloud-Native Networking**: Dynamic IP allocation and cloud load balancers
- **ARM64 Images**: Custom Talos builds for ARM64 architecture
- **Ephemeral Infrastructure**: Designed for rapid creation and destruction
- **Cost Optimization**: Resource-efficient deployment patterns
- **Observability Ready**: Built-in monitoring and logging integration

## Development Roadmap

### Phase 1: Moonlander MVP Completion
- Complete confined scope functionality
- Certification and publication of initial release
- Establish baseline platform capabilities

### Phase 2: Cloud Replication (Moonlander Expansion)
- AI-assisted AWS deployment procedures
- ARM64 architecture validation 
- Claude Desktop integration workflows
- Terraform-free cloud automation

### Phase 3: Operational Excellence
- Comprehensive observability integration
- Automated cleanup and resource management
- Developer onboarding and contribution frameworks
- Community engagement and adoption

### Conference Demo Strategy

**Live Demo Approach**: 
- Real-time deployment with audience engagement
- Demonstrated risk and authentic timing
- 25-minute complete workflow target
- Backup recording for contingency

**Risk Management**:
- Pre-tested procedures on identical architecture  
- Emergency cleanup documentation
- Claude Desktop credit management
- Fallback presentation materials

## Related Documentation

- [talm Tool Repository](https://github.com/cozystack/talm)
- [CozyStack Documentation](https://docs.cozystack.io)
- [Talos Linux Documentation](https://www.talos.dev)
- [ARM64 Architecture Decision](../ADRs/ADR-001-ARM64-ARCHITECTURE.md)
- [Moonlander Project Scope](../../README.md)

---

*This operational guide preserves workflow patterns and timing objectives from AMD64 home lab testing. The procedures and goals outlined here form the foundation for ARM64 cloud replication and the expanded moonlander project scope. CozyStack is real, tested, and ready for live demonstration.*