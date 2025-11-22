# Document: AWS Infrastructure Design for CozyStack Demo

**Repository**: `urmanac/cozystack-moon-and-back`  
**Location**: `docs/aws-infrastructure-design.md`  
**Date**: 2025-11-19  
**Status**: Design Approved

## Executive Summary

This document defines the AWS infrastructure architecture for the CozySummit Virtual 2025 demo. We use **boot-to-talos** to install our custom OCI images on EC2 instances, eliminating the need for AMI management while maintaining parity with our home lab builds.

## Architecture Overview

```
VPC: 10.10.0.0/16 (sandbox-eu-vpc - EXISTING)
└── Public Subnet: 10.10.0.0/24 (subnet-0fb2c632ccc6d99e5)
    ├── Bastion: 10.10.0.100 (ENI with static IP)
    │   - IPv6 enabled (SSH access from home/NASA)
    │   - Wireguard VPN → university NAT for IPv4
    │   - Tailscale for cluster access when bastion down
    │   - Services: registry pull-through caches, DNS
    │
    ├── Talos Gateway Node: 10.10.0.101 (t4g.medium)
    │   - Image: ghcr.io/urmanac/.../talos-arm64-gateway:latest
    │   - Extensions: drbd, zfs, spin, tailscale
    │   - Role: Subnet router + compute
    │
    ├── Talos Compute Node 2: 10.10.0.102 (t4g.medium)
    │   - Image: ghcr.io/urmanac/.../talos-arm64-compute:latest
    │   - Extensions: drbd, zfs, spin
    │
    └── Talos Compute Node 3: 10.10.0.103 (t4g.medium)
        - Image: ghcr.io/urmanac/.../talos-arm64-compute:latest
        - Extensions: drbd, zfs, spin
```

## Key Design Decisions

### 1. Use OCI Images via boot-to-talos (NOT AMIs)

**Problem**: EC2 doesn't support traditional PXE netboot  
**Solution**: Use boot-to-talos to install from our existing OCI images

**Boot Flow**:
1. Launch EC2 with any ARM64 Linux AMI (Amazon Linux 2023)
2. User-data script downloads boot-to-talos
3. boot-to-talos pulls OCI image from GHCR
4. Installs Talos to /dev/xvda with static IP config
5. Reboots into our custom Talos build

**Benefits**:
- ✅ No AMI management overhead
- ✅ Same OCI images used in home lab and cloud
- ✅ Easy updates: push new OCI tag, update Terraform
- ✅ Maintains home lab parity story for demo

### 2. Static IPs for All Nodes (No DHCP After Install)

**Implementation**: Talos kernel args configure static networking
```
ip=10.10.0.101::10.10.0.1:255.255.255.0::eth0::::
```

**Benefits**:
- ✅ No DHCP server needed after initial install
- ✅ Predictable IPs for MetalLB, kubectl access
- ✅ Survives reboots without bastion dependency

### 3. Bastion with Static ENI

**Problem**: Bastion in ASG needs predictable IP for registry caches  
**Solution**: Elastic Network Interface (ENI) with fixed IP (10.10.0.100)

**ENI Configuration**:
- Private IP: 10.10.0.100
- IPv6: Enabled (1 address)
- SourceDestCheck: **false** (enables IP forwarding for NAT)
- Attached to bastion on ASG scale-up via user-data

**User-Data ENI Attachment Logic**:
```bash
# Check if ENI already attached, detach if necessary
# Attach ENI to this instance
# Enable IP forwarding: sysctl net.ipv4.ip_forward=1
```

### 4. All Resources in Single "Public" Subnet

**Rationale**: 
- Talos nodes have IPv4 only (no public IPv4 address, no IPv6)
- "Public" subnet = has Internet Gateway, but no internet without IPv6
- Avoids DHCP broadcast problems across subnets
- Simplifies networking (Layer 2 adjacency for MetalLB ARP)

**Security**:
- Bastion: SSH allowed from single IPv6 address only
- Talos nodes: No public IP, no inbound from internet
- All communication internal or via Tailscale

### 5. No Matchbox in AWS (Home Lab Only)

**Home Lab**: Matchbox serves PXE kernel/initrd/configs  
**AWS Cloud**: boot-to-talos replaces PXE, OCI images replace matchbox assets

**Matchbox Future**: Retained for home lab Raspberry Pi netboot use cases

## Infrastructure Components

### Bastion Host

**Instance Type**: t4g.small (current) or t4g.micro  
**Scheduling**: ASG scaled 0→1 for 5 hours/day (cost optimization)  
**Networking**: 
- ENI with static IP 10.10.0.100
- IPv6 for SSH access
- Wireguard tunnel to university for IPv4 NAT

**Services** (Docker containers):
- ECR pull-through caches (ports 5050-5054)
- Pi-hole DNS (port 53)
- Tailscale subnet router (when needed)

**Not Included in AWS**:
- ❌ dnsmasq DHCP server (not needed with static IPs)
- ❌ Matchbox PXE server (boot-to-talos replaces this)

### Talos Nodes

**Quantity**: 3 nodes (1 gateway, 2 compute)  
**Instance Type**: t4g.medium (4 vCPU, 8GB RAM)  
**EBS Volume**: 50GB gp3, encrypted  
**Launch Method**: Manual EC2 instances (NOT ASG)

**Node Types** (per ADR-004):
- **Gateway**: 1 node with Tailscale extension for subnet routing
- **Compute**: 2 nodes with Spin extension only

**OCI Image References**:
```
ghcr.io/urmanac/cozystack-moon-and-back/talos-arm64-gateway:v1.8.0
ghcr.io/urmanac/cozystack-moon-and-back/talos-arm64-compute:v1.8.0
```

### Security Groups

**Bastion Security Group** (sg-0f9cb1bf403ae7dd1 - EXISTING):
- Inbound: SSH (22) from operator's IPv6 only
- Outbound: All traffic

**Talos Nodes Security Group** (NEW):
- Inbound from bastion:
  - HTTP 8080 (during boot-to-talos for OCI pull, if needed)
  - Registry caches 5050-5054 (container pulls)
  - Tailscale 41641 UDP (for coordination)
- Inbound from other Talos nodes:
  - All traffic (Kubernetes inter-node communication)
- Outbound:
  - All traffic (will route IPv4 via bastion if needed)

## Terraform Implementation Guide

### File Structure
```
modules/cozy-demo/
├── main.tf                 # Module entry point
├── bastion_eni.tf         # ENI for bastion static IP
├── talos_security_group.tf # Security group for Talos nodes
├── talos_launch_template.tf # Launch template with boot-to-talos
├── variables.tf           # Input variables
└── outputs.tf             # Resource IDs, IPs
```

### Key Resources

#### 1. Bastion ENI (`bastion_eni.tf`)
```hcl
resource "aws_network_interface" "bastion_eni" {
  subnet_id         = "subnet-0fb2c632ccc6d99e5"
  private_ips       = ["10.10.0.100"]
  security_groups   = ["sg-0f9cb1bf403ae7dd1", "sg-050d7a86b5d8e0126"]
  source_dest_check = false  # CRITICAL: enables IP forwarding
  ipv6_address_count = 1

  tags = {
    Name = "cozy-demo-bastion-eni"
    Demo = "cozystack-moon-and-back"
  }
}
```

#### 2. Talos Security Group (`talos_security_group.tf`)
```hcl
resource "aws_security_group" "talos_nodes" {
  name_prefix = "cozy-demo-talos-"
  description = "Security group for CozyStack Talos nodes"
  vpc_id      = "vpc-04af837e642c001c6"

  # Registry caches from bastion
  ingress {
    description = "Registry pull-through caches"
    from_port   = 5050
    to_port     = 5054
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.100/32"]
  }

  # Tailscale coordination
  ingress {
    description = "Tailscale from bastion"
    from_port   = 41641
    to_port     = 41641
    protocol    = "udp"
    cidr_blocks = ["10.10.0.100/32"]
  }

  # Inter-node Kubernetes traffic
  ingress {
    description = "Inter-node communication"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  # Talos API from bastion (via Tailscale)
  ingress {
    description = "Talos API"
    from_port   = 50000
    to_port     = 50001
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.100/32"]
  }

  # Kubernetes API
  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.100/32"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "cozy-demo-talos-nodes"
    Demo = "cozystack-moon-and-back"
  }
}
```

#### 3. Talos Launch Template (`talos_launch_template.tf`)
```hcl
data "aws_ami" "amazon_linux_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "talos_node" {
  for_each = var.talos_nodes

  name_prefix   = "cozy-talos-${each.value.name}-"
  image_id      = data.aws_ami.amazon_linux_arm64.id
  instance_type = "t4g.medium"

  user_data = base64encode(templatefile("${path.module}/templates/boot-to-talos.sh.tpl", {
    talos_image = "ghcr.io/urmanac/cozystack-moon-and-back/talos-arm64-${each.value.variant}:${var.talos_image_tag}"
    node_ip     = each.value.private_ip
    gateway     = "10.10.0.1"
    netmask     = "255.255.255.0"
    node_name   = each.value.name
  }))

  network_interfaces {
    associate_public_ip_address = false
    ipv6_address_count         = 0
    subnet_id                   = "subnet-0fb2c632ccc6d99e5"
    security_groups             = [aws_security_group.talos_nodes.id]
    delete_on_termination      = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = each.value.name
      Demo = "cozystack-moon-and-back"
      Role = each.value.variant
    }
  }
}
```

#### 4. Variables (`variables.tf`)
```hcl
variable "talos_nodes" {
  description = "Map of Talos nodes to create"
  type = map(object({
    name       = string
    variant    = string  # "compute" or "gateway"
    private_ip = string
  }))
  
  default = {
    gateway = {
      name       = "talos-gateway-1"
      variant    = "gateway"
      private_ip = "10.10.0.101"
    }
    compute_1 = {
      name       = "talos-compute-2"
      variant    = "compute"
      private_ip = "10.10.0.102"
    }
    compute_2 = {
      name       = "talos-compute-3"
      variant    = "compute"
      private_ip = "10.10.0.103"
    }
  }
}

variable "talos_image_tag" {
  description = "Tag for Talos OCI images from GHCR"
  type        = string
  default     = "latest"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}
```

#### 5. User-Data Template (`templates/boot-to-talos.sh.tpl`)
```bash
#!/bin/bash
set -euxo pipefail

# Log everything
exec > >(tee /var/log/boot-to-talos.log)
exec 2>&1

echo "Starting boot-to-talos installation for ${node_name}"
echo "Talos image: ${talos_image}"

# Install dependencies
dnf update -y
dnf install -y curl tar gzip

# Download boot-to-talos
BOOT_TO_TALOS_VERSION="v0.3.0"  # Update to latest
curl -LO "https://github.com/cozystack/boot-to-talos/releases/download/$${BOOT_TO_TALOS_VERSION}/boot-to-talos-linux-arm64.tar.gz"
tar -xzf boot-to-talos-linux-arm64.tar.gz
chmod +x boot-to-talos
mv boot-to-talos /usr/local/bin/

# Prepare network configuration for Talos
KERNEL_ARGS="ip=${node_ip}::${gateway}:${netmask}:${node_name}:eth0:off::"

# Run boot-to-talos (non-interactive mode)
cat > /tmp/boot-config <<EOF
${talos_image}
/dev/xvda
$${KERNEL_ARGS}
EOF

boot-to-talos --non-interactive --config /tmp/boot-config

echo "boot-to-talos installation complete. System will reboot into Talos..."
# System reboots automatically after boot-to-talos completes
```

#### 6. Outputs (`outputs.tf`)
```hcl
output "bastion_eni_id" {
  description = "ENI ID for bastion"
  value       = aws_network_interface.bastion_eni.id
}

output "bastion_static_ip" {
  description = "Static private IP for bastion"
  value       = aws_network_interface.bastion_eni.private_ip
}

output "bastion_ipv6" {
  description = "IPv6 address for bastion SSH access"
  value       = aws_network_interface.bastion_eni.ipv6_addresses
}

output "talos_launch_templates" {
  description = "Launch template IDs for Talos nodes"
  value = {
    for k, v in aws_launch_template.talos_node : k => v.id
  }
}

output "talos_node_ips" {
  description = "Static IPs assigned to Talos nodes"
  value = {
    for k, v in var.talos_nodes : k => v.private_ip
  }
}

output "talos_security_group_id" {
  description = "Security group ID for Talos nodes"
  value       = aws_security_group.talos_nodes.id
}
```

## Manual Launch Instructions

After Terraform creates launch templates, manually launch instances:

```bash
# Launch gateway node
aws ec2 run-instances \
  --region eu-west-1 \
  --launch-template LaunchTemplateName=cozy-talos-talos-gateway-1-... \
  --count 1 \
  --private-ip-address 10.10.0.101

# Launch compute node 2
aws ec2 run-instances \
  --region eu-west-1 \
  --launch-template LaunchTemplateName=cozy-talos-talos-compute-2-... \
  --count 1 \
  --private-ip-address 10.10.0.102

# Launch compute node 3
aws ec2 run-instances \
  --region eu-west-1 \
  --launch-template LaunchTemplateName=cozy-talos-talos-compute-3-... \
  --count 1 \
  --private-ip-address 10.10.0.103
```

**Why manual launch?**
- No ASG needed (avoids dynamic config problems)
- Explicit control over timing and IP assignment
- Easy to delete after demo without cleanup complexity

## Bastion User-Data Updates

Update existing bastion launch template user-data to include ENI attachment:

```bash
#!/usr/bin/env bash
set -euo pipefail

# NEW: Attach ENI if not already attached
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d ' ' -f 2)
ENI_ID="${bastion_eni_id}"  # From Terraform output

ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --region eu-west-1 \
  --network-interface-ids $ENI_ID \
  --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
  --output text 2>/dev/null || echo "None")

if [ "$ATTACHMENT_ID" != "None" ] && [ -n "$ATTACHMENT_ID" ]; then
  echo "ENI already attached, detaching..."
  aws ec2 detach-network-interface --region eu-west-1 \
    --attachment-id $ATTACHMENT_ID || true
  sleep 10
fi

echo "Attaching ENI to instance $INSTANCE_ID..."
aws ec2 attach-network-interface --region eu-west-1 \
  --network-interface-id $ENI_ID \
  --instance-id $INSTANCE_ID \
  --device-index 1

sleep 10

# Enable IP forwarding for NAT
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# EXISTING: SSH keys, Wireguard, OpenTofu, CloudWatch...
# (keep all existing bastion configuration)
```

## Cost Estimates

**Monthly costs** (assuming 5 hrs/day runtime, 30 days):

| Resource | Type | Hours/Month | Cost |
|----------|------|-------------|------|
| Bastion | t4g.small | 150 | $0.0210/hr × 150 = $3.15 |
| Talos Node 1 | t4g.medium | 150 | $0.0420/hr × 150 = $6.30 |
| Talos Node 2 | t4g.medium | 150 | $0.0420/hr × 150 = $6.30 |
| Talos Node 3 | t4g.medium | 150 | $0.0420/hr × 150 = $6.30 |
| EBS (4x 50GB) | gp3 | 720 | $0.08/GB/mo × 200GB = $16.00 |
| ENI | - | - | Free (primary ENI) |
| **Total** | | | **~$38/month** |

**Free tier offset**: t4g instances have 750 hrs/month free tier (first 12 months)
- 4 instances × 150 hrs = 600 hrs used
- Still under 750 hr limit → **Most EC2 costs covered by free tier**

**Realistic monthly cost**: ~$16-20 (mostly EBS storage)

**Demo week cost** (running full-time Dec 1-4): ~$40-50

## Validation & Testing

### Post-Deployment Checks

```bash
# 1. Verify bastion has ENI attached
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=tag:Name,Values=tf-bastion" \
  --query 'Reservations[0].Instances[0].NetworkInterfaces[*].PrivateIpAddress'
# Expected: ["10.10.0.100", ...]

# 2. Check Talos nodes booting
aws ec2 describe-instances --region eu-west-1 \
  --filters "Name=tag:Demo,Values=cozystack-moon-and-back" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress]'

# 3. Monitor boot-to-talos installation (via SSM or serial console)
aws ssm start-session --target i-xxxxx

# Inside instance, watch logs:
tail -f /var/log/boot-to-talos.log

# 4. After reboot, verify Talos API responding
talosctl -n 10.10.0.101 version
talosctl -n 10.10.0.102 version
talosctl -n 10.10.0.103 version
```

### TDG Test Suite Integration

Update Test 1 (Network Foundation) to validate:
- ✅ ENI exists with IP 10.10.0.100
- ✅ Bastion has ENI attached
- ✅ SourceDestCheck disabled on ENI

Add new Test 4a (boot-to-talos Installation):
- ✅ Instances launch with Amazon Linux
- ✅ boot-to-talos downloads successfully
- ✅ OCI image pulls from GHCR
- ✅ Talos installs to /dev/xvda
- ✅ Instance reboots into Talos

Update Test 5 (CozyStack Operational):
- ✅ Talos API responds on all nodes
- ✅ Kubernetes cluster forms (3 nodes)
- ✅ Gateway node has Tailscale active
- ✅ Compute nodes have Spin runtime loaded

## Known Limitations & Workarounds

### 1. boot-to-talos Internet Access
**Issue**: Base AMI needs internet to download boot-to-talos and pull OCI image  
**Solution**: Amazon Linux has IPv6, VPC has IGW → internet works without NAT

### 2. First Boot Duration
**Issue**: boot-to-talos installation takes 5-10 minutes  
**Solution**: Patience. Monitor via SSM or serial console. Not a problem for demo prep.

### 3. ENI Attachment Race Condition
**Issue**: If ASG replaces bastion while ENI attached elsewhere  
**Solution**: User-data script handles detach+reattach. ASG max=1 prevents multiple instances.

### 4. No Rollback on boot-to-talos Failure
**Issue**: If installation fails, instance is in broken state  
**Solution**: Terminate and re-launch. No state to lose (everything in OCI image).

## Future Enhancements

### Phase 2 (Post-Demo)
- Automate node launch via Terraform (remove manual steps)
- Add CloudWatch monitoring for Talos node health
- Implement automatic cleanup Lambda (terminate nodes after N hours)
- Create AMI from successful boot-to-talos install (faster subsequent launches)

### Phase 3 (Production-Ready)
- Multi-AZ deployment for HA
- NAT Gateway instead of Wireguard (if budget allows)
- EKS integration for managed control plane option
- Terraform Cloud workspace for state management

## References

- [ADR-004: Role-Based Talos Image Architecture](../ADRs/ADR-004-ROLE-BASED-IMAGES.html)
- [boot-to-talos GitHub](https://github.com/cozystack/boot-to-talos)
- [Talos AWS Documentation](https://www.talos.dev/latest/talos-guides/install/cloud-platforms/aws/)
- [AWS Free Tier Details](https://aws.amazon.com/free/)

---

**Document Status**: Ready for implementation in `urmanac/aws-accounts` repository

---

# Conversation Summary: Key Stumbling Blocks & Solutions

## Problem Evolution

### Initial Misunderstanding ❌
- **Assumed**: Traditional PXE netboot would work on EC2
- **Reality**: EC2 always boots from EBS/AMI, no BIOS PXE option
- **Stumbling Block**: Spent time designing DHCP/dnsmasq/matchbox before realizing netboot impossible

### First Pivot ❌
- **Proposed**: Use official Talos AWS AMIs
- **Problem**: Would need to maintain/publish our own custom AMIs for Spin+Tailscale extensions
- **Stumbling Block**: AMI management overhead defeats purpose of OCI workflow

### Final Solution ✅
- **Discovered**: You already build OCI images with custom extensions
- **Tool**: boot-to-talos installs from OCI images on any base AMI
- **Win**: No AMI management, same images work home lab + cloud

## Key Architectural Decisions

### Network Design
- **All in one subnet**: Avoids Layer 2 broadcast problems (DHCP, MetalLB ARP)
- **Static IPs via kernel args**: No DHCP server needed after boot-to-talos
- **IPv6 for bastion SSH**: No NAT gateway costs, university Wireguard for IPv4
- **SourceDestCheck: false**: Enables IP forwarding for potential NAT/routing

### Boot Strategy
- **Base AMI**: Any ARM64 Linux (Amazon Linux 2023)
- **User-data**: Downloads boot-to-talos → pulls OCI from GHCR → installs → reboots
- **No matchbox in AWS**: Not needed, boot-to-talos replaces PXE flow
- **Keep matchbox for home lab**: Raspberry Pi netboot still uses it

### Node Roles (per ADR-004)
- **Gateway node**: 1 node with Tailscale extension (subnet router)
- **Compute nodes**: 2+ nodes with Spin only (avoids Tailscale conflicts)
- **Why**: Kubernetes nodes wait for ALL extensions to be active before Ready state

### Cost Optimization
- **Bastion ASG**: Scale 0→1 for 5 hrs/day
- **t4g free tier**: 750 hrs/month covers 5 hrs/day usage
- **Manual EC2 launch**: No ASG for Talos (avoids unwanted scaling)
- **Temporary infrastructure**: Delete everything after demo (Dec 3)

## Critical Technical Details

### ENI (Elastic Network Interface)
- **Why**: Bastion needs static IP for registry caches, consistent endpoint
- **Cost**: Free (primary ENI)
- **Attachment**: User-data script handles detach+reattach if ENI already attached
- **SourceDestCheck: false**: CRITICAL setting for IP forwarding

### Security Groups
- **Bastion**: SSH from single IPv6 only
- **Talos nodes**: No public IPs, only internal + bastion traffic
- **Inter-node**: All traffic between Talos nodes (Kubernetes)

### OCI Image Flow
```
GitHub Actions → Build OCI → Push to GHCR
                                ↓
AWS User-Data → boot-to-talos → Pull OCI → Install → Reboot
                                              ↓
                                         Talos boots with
                                         custom extensions
```

## What To Remember

### When explaining to future self/others:
1. **"Why not PXE netboot on AWS?"** → EC2 doesn't support it, boot-to-talos solves this
2. **"Why not Talos AMIs?"** → We already build OCI images, no need for AMI management
3. **"Why all in one subnet?"** → Layer 2 adjacency for MetalLB, simpler networking
4. **"Why static IPs?"** → No DHCP dependency after install, predictable endpoints
5. **"Why ENI for bastion?"** → Static IP survives ASG replacements, enables IP forwarding
6. **"Where did matchbox go?"** → Only needed for home lab PXE, AWS uses boot-to-talos
7. **"How do nodes get internet?"** → IPv6 natively, or route through bastion Wireguard

### Pain points avoided:
- ❌ Building/maintaining custom AMIs
- ❌ Complex multi-subnet routing for DHCP
- ❌ NAT Gateway costs ($30+/month)
- ❌ ASG for Talos nodes (dynamic config problems)
- ❌ Public IPv4 addresses (cost + security risk)

### One-liner summary:
> "We boot AWS instances from Amazon Linux, use boot-to-talos to install our custom Talos OCI images (same ones from home lab), then nodes boot from disk with static IPs—no AMI management, no DHCP server, no NAT gateway."

---

**End of Document**
