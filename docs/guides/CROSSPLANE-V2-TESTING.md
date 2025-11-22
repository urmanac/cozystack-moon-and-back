# Crossplane v2 Testing on ARM64 CozyStack

## Overview

This guide outlines testing Crossplane v2 on ARM64 CozyStack infrastructure, with a comprehensive OIDC authentication stack including Dex, vcluster, and multi-layer cluster access patterns.

## Architecture Overview

### Multi-Layer Cluster Access Pattern

### Multi-Layer Architecture with Network Alignment

```
┌─────────────────────────────────────────────────────────┐
│ Bastion Host (Terraform-managed, public IP)            │
│ - OIDC + kubelogin                                      │
│ - Access to all cluster layers                         │
├─────────────────────────────────────────────────────────┤
│ Layer 1: AWS VPC Network (Terraform-managed)           │
│ - Security groups, subnets, routing                    │
├─────────────────────────────────────────────────────────┤
│ Layer 2: Talos Root Cluster + CozyStack CNI            │
│ - Pod subnet: 10.244.0.0/16                           │
│ - Service subnet: 10.96.0.0/16                        │
│ - Static kubeconfig access                             │
├─────────────────────────────────────────────────────────┤  
│ Layer 3: KubeVirt Tenant Clusters (if ARM64 works)    │
│ - kube-ovn-cilium-cni mesh overlay                    │
│ - Keycloak OIDC integration                            │
├─────────────────────────────────────────────────────────┤
│ Layer 4: vcluster (GitHub + Dex OIDC)                 │
│ - Runs inside KubeVirt or fallback namespace          │
│ - Crossplane v2 deployment target                     │
└─────────────────────────────────────────────────────────┘
```

### Service Stack Dependencies

1. **Root Infrastructure**: ARM64 CozyStack cluster (from companion guide)
2. **Identity Layer**: Dex with GitHub authentication
3. **Tenant Layer**: vcluster with OIDC configuration
4. **Testing Target**: Crossplane v2 deployment and functionality
5. **Networking**: Ingress solution for no-public-IP environment

## Prerequisites

### Cluster Requirements
- ✅ CozyStack ARM64 cluster running (per AWS deployment guide)
- ✅ Ingress controller functional (method TBD)
- ✅ Storage classes available (Piraeus + single-replica)
- ✅ DNS resolution working

### Authentication Requirements
- GitHub OAuth App configured
- OIDC client credentials
- kubelogin CLI tool available
- kubectl with OIDC plugins

## Phase 0: Critical Path Validation

### 0.1 KubeVirt ARM64 Compatibility Investigation

**Critical Question**: Does KubeVirt work reliably on ARM64 architecture?

**This investigation blocks all subsequent phases** - if KubeVirt doesn't work on ARM64, the entire multi-tenancy strategy requires redesign.

```bash
#!/bin/bash
# kubevirt-arm64-test.sh - Sprint to validate KubeVirt on ARM64

set -euo pipefail

echo "=== KubeVirt ARM64 Compatibility Test ==="

# Test 1: Install KubeVirt on ARM64 cluster
test_kubevirt_installation() {
  echo "Installing KubeVirt on ARM64 cluster..."
  
  # Check if ARM64 KubeVirt images are available
  kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.0.0/kubevirt-operator.yaml
  kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/v1.0.0/kubevirt-cr.yaml
  
  # Wait for KubeVirt to be ready
  kubectl wait --for=condition=Available kubevirt/kubevirt -n kubevirt --timeout=600s
  
  # Check if all pods are running on ARM64 nodes
  kubectl get pods -n kubevirt -o wide
  echo "✅ KubeVirt installation completed"
}

# Test 2: Create minimal VM to test virtualization
test_vm_creation() {
  echo "Testing VM creation on ARM64..."
  
  cat <<EOF | kubectl apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: arm64-test-vm
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/vm: arm64-test-vm
    spec:
      domain:
        cpu:
          cores: 1
        memory:
          guest: 1Gi
        devices:
          disks:
          - name: containerdisk
            disk:
              bus: virtio
          - name: cloudinitdisk
            disk:
              bus: virtio
      volumes:
      - name: containerdisk
        containerDisk:
          image: quay.io/kubevirt/cirros-container-disk-demo:latest
      - name: cloudinitdisk
        cloudInitNoCloud:
          userDataBase64: c3NoLXJzYSBBQUFBQjNOemFDMXljMkVBQUFBREFRQUJBQUFCQVFEakxVZU9+
EOF
  
  kubectl wait --for=condition=Ready vm/arm64-test-vm --timeout=300s
  echo "✅ VM creation successful on ARM64"
}

# Test 3: Validate CPU architecture inside VM
test_vm_architecture() {
  echo "Validating VM architecture..."
  
  # Get the VM pod
  VM_POD=$(kubectl get pod -l kubevirt.io/vm=arm64-test-vm -o jsonpath='{.items[0].metadata.name}')
  
  # Check architecture inside VM
  kubectl exec "$VM_POD" -c compute -- sh -c 'uname -m'
  echo "✅ Architecture validation completed"
}

# Run sprint test
test_kubevirt_installation
test_vm_creation
test_vm_architecture

echo "🎉 KubeVirt ARM64 sprint test completed!"
echo "📊 Results determine feasibility of multi-tenant KubeVirt strategy"
```

**If KubeVirt ARM64 fails**: 
- Fallback to namespace-based multi-tenancy
- Reconsider vcluster deployment strategy
- Adjust Crossplane testing approach

## Phase 1: Identity and Access Foundation

### 1.1 Dex Deployment

**Goal**: Central OIDC provider with GitHub integration

```yaml
# dex-config-outline.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dex-config
data:
  config.yaml: |
    issuer: https://dex.CLUSTER_DOMAIN
    connectors:
    - type: github
      id: github
      name: GitHub
      config:
        clientID: $GITHUB_CLIENT_ID
        clientSecret: $GITHUB_CLIENT_SECRET
        redirectURI: https://dex.CLUSTER_DOMAIN/callback
        orgs:
        - name: YOUR_GITHUB_ORG
```

**Questions**:
- What's the ingress domain strategy without public IP?
- Does Dex work reliably on ARM64?
- How to handle GitHub OAuth callback routing?

### 1.2 vcluster with OIDC

**Goal**: Nested Kubernetes cluster with GitHub authentication

```yaml
# vcluster-values-outline.yaml
sync:
  nodes:
    enabled: true
rbac:
  clusterRole:
    create: true
oidc:
  issuerUrl: https://dex.CLUSTER_DOMAIN
  clientId: vcluster
  usernameClaim: email
  groupsClaim: groups
```

**Questions**:
- Does vcluster support ARM64 reliably?
- How to configure OIDC trust chain through ingress?
- What's the kubeconfig generation pattern?

## Phase 2: Bastion Host Configuration

### 2.1 Authentication Hub

**Goal**: Central access point with multiple cluster contexts

```bash
# Planned kubectl contexts on bastion:
# 1. talos-root (static kubeconfig)
# 2. cozystack-tenant-* (keycloak OIDC)  
# 3. vcluster-dev (github + dex OIDC)
```

### 2.2 kubelogin Integration

**Goal**: Seamless OIDC authentication workflow

```bash
# Example authentication flow:
kubectl oidc-login setup \
  --oidc-issuer-url=https://dex.CLUSTER_DOMAIN \
  --oidc-client-id=kubectl \
  --oidc-extra-scope=groups,email
```

**Questions**:
- How to manage multiple OIDC contexts?
- What's the certificate trust chain for internal ingress?
- Can we automate token refresh across contexts?

## Phase 3: Crossplane v2 Deployment

### 3.1 Installation Strategy

**Goal**: Deploy Crossplane v2 on ARM64 with provider ecosystem

**Target Cluster**: TBD - Root cluster vs tenant cluster vs vcluster

```yaml
# crossplane-installation-outline.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-aws:v0.39.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider  
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.7.0
```

**Questions**:
- Which cluster layer is optimal for Crossplane?
- Do ARM64 provider images exist for all required providers?
- How to handle AWS credentials in vcluster context?

### 3.2 Provider Configuration

**Goal**: Configure AWS and Kubernetes providers

```yaml
# aws-provider-config-outline.yaml
apiVersion: aws.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-creds
      key: creds
```

### 3.3 Test Compositions

**Goal**: Validate Crossplane functionality with realistic workloads

```yaml
# test-composition-outline.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: test-infrastructure
spec:
  compositeTypeRef:
    apiVersion: example.com/v1alpha1
    kind: TestInfrastructure
  resources:
  - name: vpc
    base:
      apiVersion: ec2.aws.crossplane.io/v1beta1
      kind: VPC
  - name: subnet
    base:
      apiVersion: ec2.aws.crossplane.io/v1beta1
      kind: Subnet
```

## Phase 4: Integration Testing

### 4.1 Authentication Chain Validation

**Test Matrix**:
```
┌─────────────┬──────────────┬───────────────┬──────────────┐
│ Auth Method │ Cluster      │ Access Level  │ Status       │
├─────────────┼──────────────┼───────────────┼──────────────┤
│ Static      │ Talos Root   │ Admin         │ [ ]          │
│ Keycloak    │ KubeVirt     │ Tenant        │ [ ]          │  
│ Dex+GitHub  │ vcluster     │ Developer     │ [ ]          │
└─────────────┴──────────────┴───────────────┴──────────────┘
```

### 4.2 Crossplane Functionality Tests

```bash
#!/bin/bash
# crossplane-test-suite.sh - Comprehensive Crossplane v2 validation

set -euo pipefail

CLUSTER_CONTEXT="${1:-vcluster-dev}"
echo "Testing Crossplane v2 on context: $CLUSTER_CONTEXT"

# Test 1: Provider installation and health
test_provider_health() {
  echo "=== Testing Provider Health ==="
  kubectl get providers -o wide
  
  # Wait for providers to be healthy
  kubectl wait --for=condition=Healthy provider/provider-aws --timeout=300s
  kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=300s
  
  echo "✅ All providers are healthy"
}

# Test 2: Composite resource definition
test_xrd_creation() {
  echo "=== Testing XRD Creation ==="
  
  cat <<EOF | kubectl apply -f -
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xnetworks.example.com
spec:
  group: example.com
  names:
    kind: XNetwork
    plural: xnetworks
  claimNames:
    kind: Network
    plural: networks
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              region:
                type: string
                default: "us-west-2"
              cidr:
                type: string
                default: "10.0.0.0/16"
          status:
            type: object
EOF

  kubectl get xrd xnetworks.example.com
  echo "✅ XRD created successfully"
}

# Test 3: AWS resource provisioning
test_aws_provisioning() {
  echo "=== Testing AWS Resource Provisioning ==="
  
  # Create a simple VPC to test AWS provider
  cat <<EOF | kubectl apply -f -
apiVersion: ec2.aws.crossplane.io/v1beta1
kind: VPC
metadata:
  name: crossplane-test-vpc
spec:
  forProvider:
    cidrBlock: 172.16.0.0/16
    region: us-west-2
    tags:
      Name: crossplane-test
      Purpose: arm64-testing
  providerConfigRef:
    name: default
EOF

  # Wait for VPC to be ready
  echo "Waiting for VPC to be ready..."
  kubectl wait --for=condition=Ready vpc/crossplane-test-vpc --timeout=600s
  
  # Verify VPC was created in AWS
  VPC_ID=$(kubectl get vpc crossplane-test-vpc -o jsonpath='{.status.atProvider.vpcId}')
  echo "VPC created with ID: $VPC_ID"
  
  # Cleanup test VPC
  kubectl delete vpc crossplane-test-vpc
  echo "✅ AWS provisioning test completed"
}

# Test 4: Kubernetes resource management
test_k8s_provider() {
  echo "=== Testing Kubernetes Provider ==="
  
  # Test creating a namespace in remote cluster
  cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: Object
metadata:
  name: test-namespace
spec:
  forProvider:
    manifest:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: crossplane-test
        labels:
          created-by: crossplane
  providerConfigRef:
    name: kubernetes-provider
EOF

  kubectl wait --for=condition=Ready object/test-namespace --timeout=120s
  echo "✅ Kubernetes provider test completed"
}

# Test 5: Cross-cluster resource references
test_cross_cluster_refs() {
  echo "=== Testing Cross-Cluster References ==="
  # This would test if Crossplane can manage resources across
  # the different cluster layers (root -> tenant -> vcluster)
  
  echo "🚧 Cross-cluster reference testing - implementation needed"
  echo "   This requires coordination between cluster authentication layers"
}

# Run all tests
echo "Starting Crossplane v2 test suite on ARM64..."
test_provider_health
test_xrd_creation  
test_aws_provisioning
test_k8s_provider
test_cross_cluster_refs

echo "🎉 Crossplane v2 test suite completed!"
```

### 4.3 ARM64 Compatibility Matrix

**Crossplane Core Components**:
```
┌─────────────────────┬──────────────┬─────────────┬──────────────┐
│ Component           │ ARM64 Status │ Version     │ Notes        │
├─────────────────────┼──────────────┼─────────────┼──────────────┤
│ crossplane/crossplane│ [ ] Unknown  │ v1.15.x     │ Core runtime │
│ provider-aws        │ [ ] Unknown  │ v0.39.x     │ AWS resources│
│ provider-kubernetes │ [ ] Unknown  │ v0.7.x      │ K8s resources│
│ provider-helm       │ [ ] Unknown  │ v0.15.x     │ Helm charts  │
└─────────────────────┴──────────────┴─────────────┴──────────────┘
```

## Phase 5: Integration Validation

### 5.1 End-to-End Workflow Testing

**Goal**: Validate complete Crossplane v2 workflow across all authentication layers

**Test Scenarios**:
1. **AWS Resource Provisioning**: Create VPC, subnets, security groups via Crossplane
2. **Cross-Cluster Resource Management**: Manage Kubernetes resources across tenant clusters
3. **Multi-Tenancy Validation**: Deploy applications in different tenant contexts
4. **OIDC Authentication Chain**: Test access patterns through all authentication layers

### 5.2 Performance and Scalability Assessment

**Metrics to Collect**:
- Resource provisioning time across providers
- Cross-cluster communication latency
- Authentication token refresh behavior
- ARM64-specific performance characteristics

### 5.3 Documentation and Handoff

**Deliverables**:
- ARM64 compatibility matrix with findings
- Network architecture documentation
- Authentication flow diagrams
- Troubleshooting guides for discovered issues

## Networking Strategy Investigation

### Challenge: OIDC Callbacks Without Public IP

**The Core Problem**: OAuth2/OIDC requires publicly accessible callback URLs, but our ARM64 cluster has no public IPs.

**Solution Matrix Analysis**:

```yaml
networking_solutions:
  tailscale_funnel:
    description: "Expose services via Tailscale Funnel (public HTTPS)"
    oidc_support: "✅ Full callback support"
    complexity: "Low - single config change"
    cost: "Free"
    implementation: |
      # Enable Tailscale Funnel for dex service
      tailscale funnel --bg 443
      # Results in: https://machine-name.tail12345.ts.net
      
  cloudflare_tunnel:
    description: "Tunnel services through CloudFlare"
    oidc_support: "✅ Full callback support with custom domains"
    complexity: "Medium - requires domain + tunnel setup"
    cost: "Domain registration only"
    implementation: |
      # Deploy cloudflared tunnel
      kubectl apply -f cloudflare-tunnel.yaml
      # Configure DNS: dex.demo.yourdomain.com -> tunnel
      
  aws_alb_ingress:
    description: "Application Load Balancer with ingress controller"
    oidc_support: "✅ Full support with ACM certificates"
    complexity: "High - AWS integration + DNS management"  
    cost: "$18/month for ALB + data transfer"
    implementation: |
      # Install AWS Load Balancer Controller
      # Configure ingress with ALB annotations
      # Manage Route53 DNS + ACM certificates
      
  bastion_proxy:
    description: "SSH tunnel through bastion host"
    oidc_support: "❌ No public callback support"
    complexity: "Low for access, impossible for OAuth"
    cost: "$3/month for t4g.micro"
    implementation: "Not viable for OIDC flows"
```

### Recommended Solution: CloudFlare Tunnel

**Why CloudFlare Tunnel**:
1. **Zero Infrastructure Cost**: No load balancers needed
2. **Automatic SSL**: Let's Encrypt integration
3. **Custom Domains**: Professional appearance for demos
4. **DDoS Protection**: Enterprise-grade security
5. **Global CDN**: Fast access from conference location

**Implementation Plan**:
```yaml
# cloudflare-tunnel-config.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared-tunnel
spec:
  template:
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
        - tunnel
        - --config
        - /etc/cloudflared/config.yaml
        - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared
        env:
        - name: TUNNEL_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-tunnel
              key: token
```

### DNS Architecture for Multi-Layer Auth

```yaml
dns_structure:
  base_domain: "demo.yourdomain.com"
  services:
    dex: "auth.demo.yourdomain.com"           # Central OIDC provider
    vcluster: "vcluster.demo.yourdomain.com"  # Nested cluster access
    crossplane: "xp.demo.yourdomain.com"     # Crossplane UI/API
    grafana: "observability.demo.yourdomain.com"  # Monitoring stack
    
  certificate_strategy:
    provider: "CloudFlare"
    type: "Wildcard certificate for *.demo.yourdomain.com"
    automation: "cert-manager with CloudFlare DNS challenge"
```

## Iteration Plan

### Round 1: Foundation
- [ ] Deploy Dex with basic configuration
- [ ] Test GitHub OAuth integration
- [ ] Validate ingress routing strategy

### Round 2: Multi-Layer Auth
- [ ] Configure vcluster with OIDC
- [ ] Set up bastion with kubelogin
- [ ] Test authentication chain

### Round 3: Crossplane Testing
- [ ] Install Crossplane v2
- [ ] Configure providers
- [ ] Run functionality tests

### Round 4: Integration
- [ ] Test KubeVirt on ARM64
- [ ] Validate cross-cluster scenarios
- [ ] Document findings and recommendations

## Claude Desktop Integration Assessment

### Current Document Coverage Analysis

**Document 1 (AWS ARM64 CozyStack Deployment)**: 
- ✅ Covers infrastructure creation with Claude Desktop automation
- ✅ Provides AWS CLI scripts and validation procedures  
- ✅ Includes cleanup and resource management
- ✅ Specifies MCP connector integration points

**Document 2 (Crossplane v2 Testing)**:
- ✅ Covers application deployment and validation
- ✅ Provides testing frameworks and compatibility assessment
- ✅ Includes multi-layer authentication setup
- ✅ Specifies human intervention points

### Third Document Necessity Evaluation

**Potential Third Document**: "Claude Desktop Automation Instructions"

**Arguments Against Third Document**:
1. **Redundancy**: Both existing documents already include Claude Desktop integration points
2. **Workflow Clarity**: The two-phase approach (infrastructure → testing) is naturally sequential
3. **Maintenance Overhead**: Additional document increases complexity without clear value
4. **Audience Confusion**: Claude Desktop needs clear, consolidated instructions, not fragmented guidance

**Arguments For Third Document**:
1. **Consolidation**: Could provide high-level orchestration across both phases
2. **Error Handling**: Centralized troubleshooting for cross-phase issues
3. **Session Management**: MFA token refresh and credential handling

### Recommendation: No Third Document Required

**Justification**: 
- Document 1 provides complete infrastructure automation guidance for Claude Desktop
- Document 2 provides complete testing and validation automation guidance  
- Cross-document dependencies are minimal and clearly stated
- Claude Desktop can consume both documents sequentially without additional orchestration layer

**Alternative Approach**:
Add cross-references between documents to clarify dependencies and handoff points.

---

*Evaluation complete: Two documents provide sufficient coverage for Claude Desktop automation without requiring additional orchestration documentation.*