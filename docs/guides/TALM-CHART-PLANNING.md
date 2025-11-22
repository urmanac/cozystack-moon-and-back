# Talm Chart Planning for CozySummit Demo

**Purpose**: Plan our custom talm chart for deploying CozyStack on ARM64 Talos nodes with role-based images.

---

## 🎯 Overview

[Talm](https://github.com/cozystack/talm) is CozyStack's Helm-like tool for Talos Linux configuration management. It uses Go templates with automated discovery to create declarative, GitOps-friendly cluster configurations.

> **"Manage Talos the GitOps Way! Talm is just like Helm, but for Talos Linux"**

## 📋 Demo Requirements

### Architecture
- **ARM64-first**: All nodes running on AWS Graviton (t4g instances)
- **Role-based Images**: Different Talos images per node role
  - **Compute nodes**: `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only:demo-stable`
  - **Gateway nodes**: `ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale:demo-stable`
- **Network Setup**: Private subnet with Tailscale subnet routing
- **Demo Environment**: Optimized for live presentation on December 3, 2025

### Key Features to Demonstrate
1. **Automated Discovery**: Show talm discovering ARM64 hardware details
2. **Role-based Deployment**: Different images for different node types
3. **GitOps Workflow**: Configuration stored in Git, applied declaratively
4. **CozyStack Integration**: Seamless bootstrap to running CozyStack cluster

---

## 📁 Chart Structure Plan

Based on talm's cozystack preset, our custom chart structure:

```
cluster-demo/
├── Chart.yaml              # Chart metadata for demo cluster
├── values.yaml             # Demo-specific configuration values
├── secrets.yaml            # Encrypted secrets (git-crypt)
├── templates/
│   ├── _helpers.tpl         # Template functions and logic
│   ├── controlplane.yaml   # Control plane node template
│   ├── worker-compute.yaml  # Compute worker template (spin-only)
│   └── worker-gateway.yaml  # Gateway worker template (spin+tailscale)
├── nodes/                   # Generated node configurations
│   ├── cp1.yaml            # Control plane node 1
│   ├── worker-compute-1.yaml  # Compute worker node
│   └── worker-gateway-1.yaml # Gateway worker node
└── charts/                  # Common library chart
    └── common/              # Shared functions and queries
```

---

## ⚙️ Configuration Planning

### values.yaml (Demo-specific)
```yaml
# Demo cluster configuration
clusterName: "cozysummit-demo"

# Network configuration for AWS environment
endpoint: "https://10.0.1.100:6443"  # Control plane endpoint
clusterDomain: "cozy.demo"            # Internal cluster domain
floatingIP: "10.0.1.100"             # VIP for HA control plane

# Network subnets
podSubnets:
  - "10.244.0.0/16"
serviceSubnets:
  - "10.96.0.0/16"
advertisedSubnets:
  - "10.0.1.0/24"  # AWS private subnet

# Role-based image configuration
images:
  controlplane: "ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale:demo-stable"
  workerCompute: "ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-only:demo-stable"
  workerGateway: "ghcr.io/urmanac/cozystack-assets/talos/cozystack-spin-tailscale:demo-stable"

# Tailscale configuration for gateway nodes
tailscale:
  authkey: "{{ .Values.secrets.tailscaleAuthKey }}"  # From secrets.yaml
  subnet: "10.0.1.0/24"
  routes:
    - "10.244.0.0/16"  # Pod subnet
    - "10.96.0.0/16"   # Service subnet

# Demo-specific features
demo:
  enableMetrics: true
  exposePrometheus: true
  logLevel: "debug"

# OIDC configuration (optional for demo)
oidc:
  enabled: false  # Keep simple for demo
```

### Node Role Templates

#### templates/controlplane.yaml
```yaml
# Control plane nodes with full stack (Spin + Tailscale)
machine:
  type: controlplane
  install:
    image: "{{ .Values.images.controlplane }}"
    disk: "{{ range .Disks }}{{ if .system_disk }}{{ .device_name }}{{ end }}{{ end }}"
  
  network:
    interfaces:
      - interface: "{{ .PrimaryInterface.name }}"
        addresses:
          - "{{ .NodeIP }}/24"
        routes:
          - network: "0.0.0.0/0"
            gateway: "{{ .Gateway }}"

cluster:
  clusterName: "{{ .Values.clusterName }}"
  controlPlane:
    endpoint: "{{ .Values.endpoint }}"
  network:
    podSubnets: {{ .Values.podSubnets | toYaml | nindent 6 }}
    serviceSubnets: {{ .Values.serviceSubnets | toYaml | nindent 6 }}
```

#### templates/worker-compute.yaml
```yaml
# Compute worker nodes (Spin-only, no Tailscale)
machine:
  type: worker
  install:
    image: "{{ .Values.images.workerCompute }}"
    disk: "{{ range .Disks }}{{ if .system_disk }}{{ .device_name }}{{ end }}{{ end }}"

  # Optimized for pure compute workloads
  features:
    - name: "spin-runtime"
      enabled: true
```

#### templates/worker-gateway.yaml  
```yaml
# Gateway worker nodes (Spin + Tailscale for subnet routing)
machine:
  type: worker
  install:
    image: "{{ .Values.images.workerGateway }}"

  # Tailscale configuration for subnet routing
  features:
    - name: "tailscale-subnet-router"
      config:
        authkey: "{{ .Values.tailscale.authkey }}"
        advertiseRoutes: {{ .Values.tailscale.routes | join "," }}
```

---

## 🚀 Deployment Workflow

### 1. Initialize Chart
```bash
# Create demo cluster directory
mkdir cozysummit-demo && cd cozysummit-demo

# Initialize with our custom chart (based on cozystack preset)
talm init --preset cozystack

# Customize for our demo requirements
cp ../templates/* templates/
cp ../values.yaml .
```

### 2. Node Discovery & Templating
```bash
# Discover and template control plane
talm template -e 10.0.1.10 -n 10.0.1.10 -t templates/controlplane.yaml -i > nodes/cp1.yaml

# Discover and template compute worker  
talm template -e 10.0.1.20 -n 10.0.1.20 -t templates/worker-compute.yaml -i > nodes/worker-compute-1.yaml

# Discover and template gateway worker
talm template -e 10.0.1.30 -n 10.0.1.30 -t templates/worker-gateway.yaml -i > nodes/worker-gateway-1.yaml
```

### 3. Apply & Bootstrap
```bash
# Apply configurations to nodes
talm apply -f nodes/cp1.yaml -i
talm apply -f nodes/worker-compute-1.yaml -i  
talm apply -f nodes/worker-gateway-1.yaml -i

# Wait for reboot, then bootstrap Kubernetes
talm bootstrap -f nodes/cp1.yaml

# Get kubeconfig for CozyStack installation
talm kubeconfig kubeconfig -f nodes/cp1.yaml
export KUBECONFIG=$PWD/kubeconfig
```

### 4. Verify Role-based Deployment
```bash
# Verify nodes are using correct images
kubectl get nodes -o wide

# Check that compute nodes don't have Tailscale
kubectl get pods -A | grep -v tailscale

# Verify gateway node has Tailscale subnet routing
kubectl describe node worker-gateway-1 | grep tailscale
```

---

## 🎭 Demo Script Integration

### Key Demo Points
1. **Show automated discovery**: `talm template` discovering ARM64 hardware
2. **Demonstrate role separation**: Different images for different purposes
3. **GitOps workflow**: All config in Git, declarative application
4. **CozyStack readiness**: Cluster ready for platform installation

### Demo Commands
```bash
# 1. Quick cluster status
kubectl get nodes -o wide

# 2. Show role-based images in use
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'

# 3. Demonstrate Tailscale routing
kubectl exec -it deployment/gateway-test -- tailscale status

# 4. Show CozyStack readiness
kubectl get ns | grep cozy
```

---

## 📚 Next Steps

### Immediate Actions
1. **Study cozystack preset**: Understand existing template structure
2. **Create base templates**: Start with controlplane.yaml adaptation
3. **Plan secrets management**: git-crypt setup for Tailscale auth keys

### Development Tasks  
1. **Custom values.yaml**: Demo-specific configuration
2. **Role-based templates**: Separate templates for compute vs gateway workers
3. **Validation scripts**: Ensure role separation works correctly

### Testing & Validation
1. **Local testing**: Validate templates generate correctly
2. **ARM64 deployment**: Test on actual t4g instances
3. **CozyStack integration**: Verify platform installs successfully

---

## 🔗 References

- **Talm Repository**: https://github.com/cozystack/talm
- **CozyStack Talm Guide**: https://cozystack.io/docs/install/kubernetes/talm/
- **Cozystack Preset Source**: https://github.com/cozystack/talm/tree/main/presets/cozystack
- **Our ARM64 Images**: https://github.com/urmanac/cozystack-moon-and-back/tree/main/docs/LATEST-BUILD.md

---

**Status**: 📋 Planning Phase  
**Target**: CozySummit Virtual 2025 - December 3, 2025  
**Goal**: Demonstrate GitOps Talos management with role-based ARM64 deployment