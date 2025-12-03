# IRON-7: CozyStack ARM64 Deployment via Talm

**Mission: Deploy CozyStack on ARM64 using Talm (Talos GitOps Manager)**  
**Date: December 2, 2025**  
**Target: Full CozyStack cluster for tomorrow's demo**

## Mission Overview

We're deploying a complete CozyStack cluster on ARM64 using Talm instead of raw talosctl. This approach will give us:
- ✅ Proper discovery-based hardware configuration
- ✅ GitOps-friendly patch management  
- ✅ Clean node configs without default CNI
- ✅ CozyStack-ready bare metal configuration

## Phase 1: Initial Talos Node Deployment

### Step 1.1: Deploy Base Talos Node
We'll first deploy a single Talos node in maintenance mode using our existing script, then use Talm to discover and configure it properly.

```bash
# Run from local machine
export AWS_PROFILE=sb-terraform-mfa-session
./simple-talos-launch.sh
```

This creates a single ARM64 node at `10.10.1.119` that we can interrogate with Talm.

### Step 1.2: Install Talm on Bastion (10.10.1.100)

```bash
# SSH to bastion
ssh ec2-user@10.10.1.100

# Install Talm
curl -sSL https://github.com/cozystack/talm/raw/refs/heads/main/hack/install.sh | sh -s

# Verify installation
talm version
```

## Phase 2: Talm Project Initialization

### Step 2.1: Initialize CozyStack Talm Project

```bash
# On bastion host
mkdir cozystack-cluster
cd cozystack-cluster
talm init -p cozystack
```

This creates:
- `templates/` directory with CozyStack-specific Talos templates
- Base project structure for GitOps management

### Step 2.2: Discover Node Hardware

```bash
# Gather node information from our deployed node
talm -n 10.10.1.119 -e 10.10.1.119 template -t templates/controlplane.yaml -i > nodes/node1.yaml
```

This will:
- Connect to the Talos node at 10.10.1.119
- Discover hardware (disks, network interfaces, etc.)
- Generate a node-specific configuration file
- Include commented hardware discovery for reference

## Phase 3: Configuration Customization

### Step 3.1: Review Discovered Configuration

The generated `nodes/node1.yaml` will contain:
- **Discovered Network Interfaces**: AWS EC2 ARM64 networking setup
- **Discovered Disks**: EBS volumes and local storage
- **Base CozyStack Configuration**: Templates for bare node setup

### Step 3.2: Customize for CozyStack

Edit `nodes/node1.yaml` to:
- Set correct cluster endpoint: `https://10.10.1.119:6443`
- Configure registry mirrors (our existing 5-mirror setup)
- Ensure no default CNI (CozyStack will provide this)
- Set custom install image if needed

## Phase 4: Deployment and Bootstrap

### Step 4.1: Apply Talm Configuration

```bash
# Apply the discovered and customized configuration
talm apply -f nodes/node1.yaml -i
```

### Step 4.2: Bootstrap Cluster

```bash
# Bootstrap the cluster using Talm
talm bootstrap -f nodes/node1.yaml
```

## Phase 5: CozyStack Installation

Once we have a clean Talos cluster with proper bare node configuration:

### Step 5.1: Export Kubeconfig

```bash
talm kubeconfig -f nodes/node1.yaml
```

### Step 5.2: Install CozyStack

```bash
# Install CozyStack on the clean cluster
kubectl apply -f https://raw.githubusercontent.com/cozystack/cozystack/main/packages/system/cozystack/manifests.yaml
```

## Expected Outcomes

1. **Clean ARM64 Talos Node**: Properly discovered hardware configuration
2. **CozyStack-Ready Cluster**: No conflicting CNI, clean for CozyStack installation  
3. **GitOps Managed**: All configuration stored in version-controllable files
4. **Demo Ready**: Full CozyStack platform on ARM64 for tomorrow's presentation

## Key Differences from Previous Approach

- **Hardware Discovery**: Talm automatically detects and configures hardware
- **Template-Based**: Uses CozyStack-specific templates instead of generic Talos
- **GitOps Ready**: Configuration files can be committed and versioned
- **Clean State**: No default Kubernetes components that conflict with CozyStack

---

## Execution Log

### Phase 1: Base Node Deployment ✅ COMPLETED
- **Instance Created**: `i-071d53eed6d0978da` at `10.10.1.119`
- **Endpoint**: `https://10.10.1.119:6443`
- **Files Generated**: `talosconfig`, `controlplane.yaml`, `worker.yaml`
- **Status**: Ready for Talm discovery

### **CRITICAL DISCOVERY**: Node Not in Maintenance Mode ⚠️

The node deployed with our script is **not in maintenance mode** - it's a pre-configured node waiting for bootstrap! 

**Problem**: Talm requires maintenance mode nodes for hardware discovery
**Solution**: Two paths forward:

#### **Path A: Quick Bootstrap (Recommended for Demo Tomorrow)**
Use existing talosctl approach since we have valid configs:

```bash
# Copy talosconfig to bastion
scp talosconfig ec2-user@10.10.1.100:~/

# On bastion: Bootstrap existing cluster
export TALOSCONFIG=~/talosconfig  
talosctl config endpoint 10.10.1.119
talosctl config nodes 10.10.1.119
talosctl bootstrap
talosctl health

# Get kubeconfig and proceed with CozyStack
talosctl kubeconfig .
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

#### **Path B: True Talm Approach (Deploy Maintenance Mode)**
Modify launch script to deploy maintenance-mode nodes that Talm can discover.

**Recommendation**: Use Path A for tomorrow's demo, document Path B for future proper Talm workflow.

### **CRITICAL BREAKTHROUGH ATTEMPT**: Direct Talos AMI in Maintenance Mode

**Problem**: boot-to-talos kexec failing due to memfd_create userspace/kernel mismatch
**Solution**: Deploy official Talos AMI directly in maintenance mode

**New Strategy**:
1. **Skip boot-to-talos entirely** - use official Talos ARM64 AMI  
2. **Boot into maintenance mode** by default
3. **Use Talm to configure with CozyStack image** via machine configs
4. **Apply custom install image** through Talm templates

**Commands for immediate attempt**:
```bash
# Find official Talos ARM64 AMI  
aws ec2 describe-images --region eu-west-1 --owners 540036508848 \
  --filters "Name=name,Values=talos-v1.11.5-arm64" \
  --query 'Images[0].ImageId' --output text

# Deploy directly into maintenance mode (no custom image needed initially)
# Then use Talm to configure the custom CozyStack image
```

### Next Steps for Bastion (10.10.1.100):

1. **Install Talm**:
```bash
ssh ec2-user@10.10.1.100
curl -sSL https://github.com/cozystack/talm/raw/refs/heads/main/hack/install.sh | sh -s
```

2. **Initialize Talm Project**:
```bash
mkdir cozystack-cluster && cd cozystack-cluster
talm init -p cozystack
```

3. **Wait for Talos Node Ready** (~3 minutes), then **Discover Hardware**:
```bash
# Test if node is ready
talosctl -n 10.10.1.119 -e 10.10.1.119 health --server=false

# Once ready, discover with Talm
talm -n 10.10.1.119 -e 10.10.1.119 template -t templates/controlplane.yaml -i > nodes/node1.yaml
```

4. **Review and Customize** `nodes/node1.yaml` for CozyStack requirements
