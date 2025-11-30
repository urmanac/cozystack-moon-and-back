# CozyStack ARM64 Deployment on AWS

## Overview

This guide provides a straightforward approach to deploying CozyStack on ARM64 EC2 instances using AWS CLI and dynamic resource lookup. The process is designed for Claude Desktop automation using filesystem, Kubernetes MCP, and AWS API connectors with pre-configured IAM admin access.

## Prerequisites

### AWS Environment
- AWS CLI configured with MFA'd session token (Admin access)
- VPC with subnets configured via existing Terraform (bastion + security groups)
- Bastion host with OCI pull-through cache for GHCR access
- Claude Desktop will identify any missing IAM requirements during execution

### Local Tools
- `talm` CLI tool
- `kubectl`
- AWS CLI v2

## Infrastructure Manifest

### Node Manifest Structure (`cluster-manifest.yaml`)

```yaml
apiVersion: v1
kind: ClusterManifest
metadata:
  name: cozystack-arm64-cluster
  region: us-west-2
spec:
  vpc:
    id: vpc-04af837e642c001c6
    region: eu-west-1
    subnets:
      - subnet-0ef9817bc457d9d76  # Private subnet 1 (AZ-A)
      - subnet-0b68a5b909d77cb4c  # Private subnet 2 (AZ-B)
      - subnet-0fb2c632ccc6d99e5  # Public subnet 1 (AZ-A) 
      - subnet-07a140ab2b20bf89b  # Public subnet 2 (AZ-B)
  nodes:
    controlPlane:
      - name: control-01
        instanceType: c7g.large
        subnet: subnet-0ef9817bc457d9d76  # Private AZ-A
        privateIP: 10.10.2.10
        availabilityZone: eu-west-1a
      - name: control-02
        instanceType: c7g.large
        subnet: subnet-0b68a5b909d77cb4c  # Private AZ-B
        privateIP: 10.10.3.10
        availabilityZone: eu-west-1b
      - name: control-03
        instanceType: c7g.large
        subnet: subnet-0ef9817bc457d9d76  # Private AZ-A
        privateIP: 10.10.2.11
        availabilityZone: eu-west-1a
    workers:
      - name: worker-01
        instanceType: c7g.xlarge
        subnet: subnet-0b68a5b909d77cb4c  # Private AZ-B
        privateIP: 10.10.3.20
        availabilityZone: eu-west-1b
      - name: worker-02
        instanceType: c7g.xlarge
        subnet: subnet-0ef9817bc457d9d76  # Private AZ-A  
        privateIP: 10.10.2.20
        availabilityZone: eu-west-1a
  baseImage:
    filter:
      name: "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-*"  # Dynamic lookup for latest Ubuntu ARM64
      architecture: arm64
      virtualizationType: hvm
    bootToTalos:
      enabled: true
      customImage: "ghcr.io/urmanac/cozystack-assets/talos:demo-stable"  # Real custom Talos image
      registryCache: "10.10.1.100:5000"  # Bastion registry cache endpoint
    userData: |
      #cloud-config
      # Boot-to-Talos configuration - downloads custom image and kexecs early in boot
  cluster:
    name: cozystack-arm64
    endpoint: https://10.10.1.200:6443  # Control plane load balancer VIP
    domain: cluster.local
    securityGroupId: sg-0e6b4a78092854897  # Talos cluster security group
```

## 🎉 **Infrastructure Ready for Launch!**

Based on Terraform outputs, we have everything needed for ARM64 Talos deployment:

### **Real Infrastructure Values (Updated November 30th)**
- **VPC**: `vpc-04af837e642c001c6` (eu-west-1, 10.10.0.0/16)
- **Private Subnets**: `subnet-0ef9817bc457d9d76` (AZ-A), `subnet-0b68a5b909d77cb4c` (AZ-B)
- **Registry Cache**: `10.10.1.100:5000` (GHCR pull-through on bastion)
- **Security Group**: `sg-0e6b4a78092854897` (Kubernetes + Talos ports)
- **Custom Talos Image**: `ghcr.io/urmanac/cozystack-assets/talos:demo-stable`

### **OIDC Authentication Bonus** 🎯
The aws-accounts Claude also implemented GitHub Actions OIDC authentication, enabling serverless CI/CD pipelines!

### 1. Pre-flight Validation
- [ ] AWS credentials and MFA configured
- [ ] VPC and subnets available
- [ ] Security groups configured for Kubernetes ports
- [ ] Bastion host OCI pull-through cache operational
- [ ] Ubuntu ARM64 AMI identified for target region
- [ ] Custom Talos image accessible via registry cache
- [ ] Instance type availability verified

### 2. Infrastructure Creation Script

**Target**: Simple script that reads `cluster-manifest.yaml` and creates EC2 instances

```bash
#!/bin/bash
# create-cluster.sh - AWS EC2 instance creation from manifest
set -euo pipefail

MANIFEST_FILE="${1:-cluster-manifest.yaml}"
REGION=$(yq '.spec.vpc.region // "us-west-2"' "$MANIFEST_FILE")

echo "Creating CozyStack ARM64 cluster from manifest: $MANIFEST_FILE"

# Dynamic Ubuntu ARM64 AMI lookup - base image for boot-to-Talos
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=arm64" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)
echo "Using Ubuntu ARM64 AMI: $AMI_ID (will boot-to-Talos)"

# Parse manifest and extract node definitions
NODES=$(yq '.spec.nodes.controlPlane[], .spec.nodes.workers[]' "$MANIFEST_FILE")

# Generate boot-to-Talos user data
CUSTOM_TALOS_IMAGE=$(yq '.spec.baseImage.bootToTalos.customImage' "$MANIFEST_FILE")
REGISTRY_CACHE=$(yq '.spec.baseImage.bootToTalos.registryCache' "$MANIFEST_FILE")

cat > boot-to-talos-userdata.yaml << EOF
#cloud-config
write_files:
- path: /opt/boot-to-talos.sh
  permissions: '0755'
  content: |
    #!/bin/bash
    # Download custom Talos image via registry cache
    docker pull ${REGISTRY_CACHE}/$(echo ${CUSTOM_TALOS_IMAGE} | cut -d'/' -f2-)
    # Extract and kexec into Talos
    # Implementation details for early boot transition
runcmd:
- /opt/boot-to-talos.sh
EOF

# Create security group for cluster if not exists
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=cozystack-cluster" \
  --query 'SecurityGroups[0].GroupId' \
  --output text 2>/dev/null || echo "None")

if [[ "$SECURITY_GROUP_ID" == "None" ]]; then
  echo "Creating security group for cluster..."
  SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name cozystack-cluster \
    --description "CozyStack ARM64 cluster security group" \
    --vpc-id "$(yq '.spec.vpc.id' "$MANIFEST_FILE")" \
  # Check if instance profile is needed for node operations
  INSTANCE_PROFILE_ARG=""
  if aws iam get-instance-profile --instance-profile-name CozyStackNodeRole 2>/dev/null; then
    INSTANCE_PROFILE_ARG="--iam-instance-profile Name=CozyStackNodeRole"
  fi
  
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --private-ip-address "$PRIVATE_IP" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --user-data file://boot-to-talos-userdata.yaml \
    $INSTANCE_PROFILE_ARG \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NODE_NAME},{Key=Cluster,Value=cozystack-arm64}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
  
  # Configure security group rules for Kubernetes
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 6443 --source-group "$SECURITY_GROUP_ID"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 50000 --source-group "$SECURITY_GROUP_ID"  
  # Configure security group rules for Kubernetes
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 6443 --source-group "$SECURITY_GROUP_ID"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 50000 --source-group "$SECURITY_GROUP_ID"  
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 2379-2380 --source-group "$SECURITY_GROUP_ID"
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 10250 --source-group "$SECURITY_GROUP_ID"
  # Add registry cache access from cluster nodes to bastion
  aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp --port 5000 --cidr "10.0.0.0/16"
fi

### 2.1 Security Group Configuration

**Required Ports for CozyStack**:
- `6443/tcp`: Kubernetes API server
- `50000/tcp`: Talos API
- `2379-2380/tcp`: etcd client/peer communication  
- `10250/tcp`: kubelet API
- `10251/tcp`: kube-scheduler
- `10252/tcp`: kube-controller-manager
- `80,443/tcp`: Ingress HTTP/HTTPS
- `30000-32767/tcp`: NodePort services
- `5000/tcp`: Registry cache access to bastion

# Create EC2 instances with specified private IPs
while IFS= read -r node; do
  NODE_NAME=$(echo "$node" | yq '.name')
  INSTANCE_TYPE=$(echo "$node" | yq '.instanceType')
  SUBNET_ID=$(echo "$node" | yq '.subnet')
  PRIVATE_IP=$(echo "$node" | yq '.privateIP')
  AZ=$(echo "$node" | yq '.availabilityZone')
  
  echo "Creating instance: $NODE_NAME ($INSTANCE_TYPE) in $AZ"

# Create EC2 instances with specified private IPs
while IFS= read -r node; do
  NODE_NAME=$(echo "$node" | yq '.name')
  INSTANCE_TYPE=$(echo "$node" | yq '.instanceType')
  SUBNET_ID=$(echo "$node" | yq '.subnet')
  PRIVATE_IP=$(echo "$node" | yq '.privateIP')
  AZ=$(echo "$node" | yq '.availabilityZone')
  
  echo "Creating instance: $NODE_NAME ($INSTANCE_TYPE) in $AZ"
  
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$(yq '.spec.talos.image' "$MANIFEST_FILE")" \
    --instance-type "$INSTANCE_TYPE" \
    --subnet-id "$SUBNET_ID" \
    --private-ip-address "$PRIVATE_IP" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NODE_NAME},{Key=Cluster,Value=cozystack-arm64}]" \
    --query 'Instances[0].InstanceId' \
    --output text)
    
  echo "Created instance $INSTANCE_ID for node $NODE_NAME"
  echo "$NODE_NAME:$INSTANCE_ID:$PRIVATE_IP" >> cluster-instances.txt
done <<< "$NODES"

# Wait for all instances to be running
echo "Waiting for instances to be ready..."
while IFS=: read -r node_name instance_id private_ip; do
  aws ec2 wait instance-running --instance-ids "$instance_id"
  echo "Instance $node_name ($instance_id) is running"
done < cluster-instances.txt

echo "All instances created successfully!"
echo "Instance details saved to: cluster-instances.txt"
```

### 2.1 Security Group Configuration

**Required Ports for CozyStack**:
- `6443/tcp`: Kubernetes API server
- `50000/tcp`: Talos API
- `2379-2380/tcp`: etcd client/peer communication  
- `10250/tcp`: kubelet API
- `10251/tcp`: kube-scheduler
- `10252/tcp`: kube-controller-manager
- `80,443/tcp`: Ingress HTTP/HTTPS
- `30000-32767/tcp`: NodePort services

### 2.2 Bastion Host OCI Pull-through Cache Configuration

**Critical Dependency**: GHCR access from private VPC requires registry cache

```bash
#!/bin/bash
# bastion-registry-cache-setup.sh - Configure OCI pull-through cache

# Install Docker registry on bastion host
sudo docker run -d \
  --name registry-cache \
  --restart=always \
  -p 5000:5000 \
  -e REGISTRY_PROXY_REMOTEURL=https://ghcr.io \
  -e REGISTRY_PROXY_USERNAME="$GHCR_USERNAME" \
  -e REGISTRY_PROXY_PASSWORD="$GHCR_TOKEN" \
  -v /opt/registry-cache:/var/lib/registry \
  registry:2

# Configure DNS or host entries for cluster nodes to use cache
# cluster-nodes should resolve ghcr.io -> bastion-host:5000
# Or configure docker daemon.json with registry mirrors
```

**IPv6 Considerations**:
- GHCR IPv6 capability unknown
- Pull-through cache ensures reliable access
- Custom Talos image cached before cluster deployment

### 3. Talos Cluster Bootstrap

**Target**: Boot-to-Talos from Ubuntu base with custom image

**Process Overview**:
1. **Ubuntu Boot**: EC2 instances start with Ubuntu 22.04 ARM64
2. **Early Transition**: cloud-init downloads custom Talos image via registry cache
3. **Kexec to Talos**: System transitions to custom Talos image early in boot
4. **Talos Initialization**: Standard talm workflow begins with custom image

**Boot-to-Talos Implementation**:
```bash
#!/bin/bash
# Expanded boot-to-talos.sh script
set -euo pipefail

REGISTRY_CACHE="${BASTION_HOST}:5000"
TALOS_IMAGE="ghcr.io/your-org/talos:v1.10.5-cozy-spin"

# Configure Docker to use registry cache
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["http://${REGISTRY_CACHE}"]
}
EOF

# Pull custom Talos image
docker pull "${REGISTRY_CACHE}/$(echo ${TALOS_IMAGE} | cut -d'/' -f2-)"

# Extract kernel and initrd for kexec
# Mount image, extract /boot files
# Execute kexec with Talos kernel and initrd
# System transitions to Talos immediately
```

**Standard talm Workflow** (post-transition):
- Initialize talm with CozyStack preset
- Generate ARM64-specific node configurations  
- Apply configurations to Talos instances
- Bootstrap cluster with HA control plane
- Validate cluster connectivity

### 4. CozyStack Platform Installation

**Target**: Complete platform deployment with all optional components

- [ ] Core CozyStack installation
- [ ] Dashboard deployment and configuration
- [ ] OIDC integration setup
- [ ] Piraeus storage backend
- [ ] ETCD configuration
- [ ] Single-replica storage class creation
- [ ] Network ingress configuration

### 5. Validation and Testing

**Target**: Automated test suite to verify deployment success

```bash
#!/bin/bash
# test-cluster.sh - Validation test suite

# Test cluster API accessibility
# Verify all nodes healthy and ready
# Test CozyStack operator functionality
# Validate tenant cluster creation
# Test ingress and storage functionality
# Generate success/failure report
```

## Networking Considerations

### Challenge: No Public IPv4

Since cloud instances lack direct public IP access, ingress strategy needs investigation:

**Option 1: Tailscale Overlay Network**
```bash
# Install Tailscale on cluster nodes during bootstrap
# Configure subnet routing for cluster networks
# Access services through VPN connectivity

# Pros: Simple, secure, familiar pattern from home lab
# Cons: Requires Tailscale setup on client, potential latency
# OIDC: Should work well for callback URLs via tailnet domains
```

**Option 2: AWS Application Load Balancer**
```yaml
# Use ALB with target groups pointing to worker nodes
# Configure listeners for HTTP/HTTPS traffic
# SSL termination at load balancer level

apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  type: LoadBalancer
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https  
    port: 443
    targetPort: 443
```

**Option 3: Bastion Host with Port Forwarding**
```bash
# Create single t4g.micro instance with public IP
# SSH tunneling for service access
# kubectl proxy through bastion for cluster access

# Example access pattern:
ssh -L 8080:internal-service.cluster.local:80 bastion-host
curl http://localhost:8080
```

**Option 4: CloudFlare Tunnel (Zero Trust)**
```yaml
# Deploy cloudflared as DaemonSet
# Tunnel cluster services through CloudFlare network
# Custom domains with automatic SSL certificates

# Pros: No load balancer costs, automatic SSL, DDoS protection
# Cons: Dependency on CloudFlare, requires domain setup
```

### Recommended Approach: Hybrid Strategy

1. **Tailscale for Development**: Fast setup, secure access for testing
2. **ALB for Production**: Once ingress patterns are validated
3. **CloudFlare for Demo**: Clean URLs for conference presentation
4. **Registry Cache for Reliability**: Bastion-hosted cache for GHCR access

### DNS Strategy

```yaml
# Example DNS configuration for different approaches
approaches:
  tailscale:
    pattern: "service-name.tail12345.ts.net"
    ssl: "automatic via Tailscale"
    
  alb:
    pattern: "service-name.cluster.example.com"  
    ssl: "ACM certificate required"
    
  cloudflare:
    pattern: "service-name.demo.example.com"
    ssl: "automatic via CloudFlare"
    
  registry_cache:
    pattern: "bastion-host:5000"
    ssl: "HTTP only (internal VPC)"
    purpose: "GHCR proxy for image pulls"
```

## Networking Architecture

### Network Architecture Layers

**Layer 1: AWS VPC Network (Terraform-managed)**
- AWS VPC with subnets for control plane and workers
- Security groups for Kubernetes and Talos communication
- Bastion host with public IP and registry cache
- Private subnets with NAT Gateway for outbound access

**Layer 2: CozyStack Talos CNI Network**
- Pod subnet: 10.244.0.0/16 (default Flannel/CNI)
- Service subnet: 10.96.0.0/16 (ClusterIP services)
- Node-to-node communication via VPC private IPs
- Integration with AWS VPC routing

**Layer 3: kube-ovn-cilium-cni Mesh (KubeVirt Clusters)**
- Overlay network for tenant KubeVirt clusters
- Inter-cluster communication and isolation
- Integration with CozyStack multi-tenancy
- ARM64 compatibility to be validated

### Registry Cache Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ GHCR (IPv6?)    │────▶│ Bastion Registry │────▶│ Cluster Nodes   │
│ ghcr.io         │     │ Cache :5000      │     │ (private VPC)   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                               │
                        ┌─────────────────┐
                        │ Custom Talos    │
                        │ Image Storage   │
                        └─────────────────┘
```

### Questions for Investigation:
1. Does Talos ARM64 support Tailscale natively?
2. What's the minimal ingress configuration for CozyStack?
3. Can we use AWS ELB/ALB with CozyStack's ingress controller?
4. How does kube-ovn-cilium-cni integrate with Talos CNI on ARM64?
5. Does GHCR require IPv6, and how reliable is the registry cache approach?

## Cleanup and Resource Management

### Emergency Cleanup Script

```bash
#!/bin/bash
# cleanup-cluster.sh - Complete resource removal

# Terminate all cluster EC2 instances
# Remove associated EBS volumes
# Clean up security groups if created
# Remove load balancers and target groups
# Generate cleanup verification report
```

## Claude Desktop Integration Points

### MCP Connector Usage:
1. **Filesystem Connector**: Read manifest, write scripts, manage configurations
2. **Kubernetes MCP**: Validate cluster state, deploy CozyStack components
3. **AWS API MCP**: Create instances, manage networking, configure load balancers

### Human Intervention Points:
- MFA token entry for AWS session
- Final deployment verification
- Cleanup decision (manual trigger)

## Next Steps

1. Implement manifest parsing logic
2. Create EC2 instance provisioning script
3. Develop ARM64 Talos configuration templates
4. Build automated validation test suite
5. Design ingress strategy for no-public-IP environment

---

*This guide serves as the foundation for Claude Desktop automated deployment of CozyStack on ARM64 infrastructure.*