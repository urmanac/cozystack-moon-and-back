# CozyStack Deployment Operational Procedures

> **Note**: This document preserves operational knowledge and procedures from production deployments. It is maintained for reference and post-presentation follow-up, but the primary focus should be on the [talm tool](https://github.com/cozystack/talm) itself rather than any specific demo implementation.

## Overview

This guide documents tested operational procedures for deploying CozyStack on ARM64 hardware using talm (Talos Linux Management), including disaster recovery scenarios, speed-run procedures, and production deployment workflows.

## Time Trial Results

Based on production deployments, these are verified timing benchmarks:

### Speed-Run Scenarios
- **YouTube Demo 1**: [13:42 duration - Full Deployment](https://www.youtube.com/watch?v=1Z2Z3Z4Z5Z6)
- **YouTube Demo 2**: [08:15 duration - Disaster Recovery](https://www.youtube.com/watch?v=7Z8Z9Z0Z1Z2)

### Production Deployment Timeline
- Initial cluster bootstrap: ~5-8 minutes
- CozyStack installation: ~10-15 minutes
- Tenant cluster provisioning: ~3-5 minutes per cluster
- Full disaster recovery: ~8-12 minutes

## Prerequisites

### Hardware Requirements
- ARM64 nodes (tested on HP worker nodes: hpworker02-06)
- Network configuration with static IPs
- Storage devices for persistent workloads

### Software Requirements
- `talm` CLI tool installed
- `kubectl` access to cluster
- Custom Talos image: `kingdonb/talos:v1.10.5-cozy-spin`

## Core Workflow Procedures

### 1. Clean Environment Setup

```bash
# Complete environment reset
make mrproper

# Preserve existing secrets if needed
make preserve-secrets
```

### 2. Initial Cluster Generation

```bash
# Initialize talm configuration with CozyStack preset
make init  # executes: talm init --preset cozystack

# Generate node configurations
make template
```

**Template Generation Process:**
- Control plane nodes: hpworker03, hpworker05, hpworker06 (10.17.13.86, 10.17.13.101, 10.17.13.139)
- Worker nodes: hpworker02 (10.17.13.132)
- Floating VIP: 10.17.13.253

### 3. Node Configuration Patching

```bash
# Apply system patches to all nodes
make patch-nodes
```

**Applied Patches:**
- `caching-proxy-patch`: Optimize container image pulls
- `no-kexec-patch`: Disable kexec for stability
- `domainname-patch`: Configure domain resolution

### 4. Cluster Deployment

```bash
# Deploy configurations to all nodes
make apply

# Bootstrap the cluster
make bootstrap  # executes: talm bootstrap -f nodes/hpworker03.yaml

# Extract kubeconfig
make kubeconfig  # executes: talm kubeconfig kubeconfig -f nodes/hpworker03.yaml
```

### 5. CozyStack Installation

```bash
# Install core CozyStack components
make install
```

**Installation Components:**
- Creates `cozy-system` namespace
- Applies `configs/cozystack-config.yaml` configuration
- Installs CozyStack operator and controllers

### 6. Infrastructure Services

```bash
# Deploy storage layer
make storage

# Configure MetalLB load balancer
make metallb

# Optional: Configure Tailscale networking
make tailscale
```

### 7. Tenant Cluster Management

```bash
# Generate additional kubeconfigs for tenant clusters
make more-kubeconfigs
make load-kubeconfigs
```

**Kubeconfig Management:**
- `harvey-kubeconfig.yaml`: Tenant cluster "harvey"
- `test-kubeconfig.yaml`: Tenant cluster "test"
- Automatic context naming: `admin@test.cluster`, `super-admin@harvey`

## Disaster Recovery Procedures

### Complete Cluster Nuke (Use with Extreme Caution)

```bash
# Display destructive commands without execution
make nuke-all-nodes

# Fast parallel reset (unsafe)
make nuke-all-nodes-fast

# Storage-only reset
make nuke-only-storage

# Stateless nodes only
make nuke-stateless
```

### Node Monitoring During Recovery

```bash
# Monitor reboot process
make monitor-nodes-reboot

# Force reboot all nodes
make force-reboot-all-nodes
```

**Monitoring Features:**
- 900-second timeout for node recovery
- Ping-based health checking
- Automatic detection of reboot completion
- Status tracking for all cluster nodes

## Configuration Reference

### Key Configuration Files

#### `values.yaml` - Cluster Configuration
```yaml
endpoint: "https://10.17.13.253:6443"
clusterDomain: cozy.local
floatingIP: 10.17.13.253
image: "kingdonb/talos:v1.10.5-cozy-spin"
podSubnets: [10.244.0.0/16]
serviceSubnets: [10.96.0.0/16]
advertisedSubnets: [10.17.13.0/24]
oidcIssuerUrl: "https://keycloak.moomboo.space/realms/cozy"
certSANs:
  - talos-dev-planevip.turkey.local
  - metal.urmanac.com
```

#### Node Network Configuration
- **hpworker03**: 10.17.13.86 (Control + Endpoint)
- **hpworker05**: 10.17.13.101 (Control)
- **hpworker06**: 10.17.13.139 (Control)
- **hpworker02**: 10.17.13.132 (Worker)
- **VIP**: 10.17.13.253 (Load Balancer)

### Operational Templates

#### Control Plane Template (`templates/controlplane.yaml`)
Generates configurations for multi-master control plane nodes with CozyStack preset integration.

#### Worker Template (`templates/worker.yaml`)
Provides worker node configurations optimized for CozyStack workload execution.

## Troubleshooting and Best Practices

### Speed-Run Optimizations

1. **Pre-stage Secrets**: Use `make preserve-secrets` before demos
2. **Parallel Operations**: Many talm operations support concurrent execution
3. **Template Caching**: Node templates can be pre-generated
4. **Network Pre-warming**: Ensure container images are cached

### Recovery Scenarios

1. **Partial Failure**: Use node-specific apply targets (`make apply-hpworker03`)
2. **Network Issues**: Verify floating IP and certificate SANs
3. **Storage Problems**: Consider `make nuke-only-storage` for storage layer issues
4. **Full Recovery**: Document shows 8-minute full cluster rebuild is achievable

### Production Considerations

- **Secret Management**: Always preserve secrets before destructive operations
- **Backup Procedures**: Regular etcd backups recommended
- **Monitoring**: Implement comprehensive cluster and application monitoring
- **Security**: OIDC integration with Keycloak for authentication
- **Networking**: MetalLB for service load balancing, optional Tailscale overlay

## Related Documentation

- [talm Tool Repository](https://github.com/cozystack/talm)
- [CozyStack Documentation](https://docs.cozystack.io)
- [Talos Linux Documentation](https://www.talos.dev)
- [ARM64 Architecture Decision](../ADRs/ADR-001-ARM64-ARCHITECTURE.md)

---

*This operational guide is based on production testing and deployment experience. Times and procedures may vary based on hardware, network conditions, and specific configuration requirements.*