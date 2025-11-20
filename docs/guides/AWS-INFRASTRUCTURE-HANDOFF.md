# AWS Infrastructure Implementation Handoff for Claude Desktop

**Target**: eu-west-1  
**Account**: Urmanac AWS Sandbox  
**Architecture**: 10.10.0.0/16 VPC, single public subnet (per Claude Desktop analysis)  
**Boot Strategy**: boot-to-talos with existing OCI images (no AMI management)  
**Constraint**: AWS Free Tier compliance (~$16-20/month for EBS)  

## 🎯 Mission: boot-to-talos ARM64 Validation

**BREAKTHROUGH: Use boot-to-talos instead of traditional PXE netboot!**

### Prerequisites (Images Available ✅)
- ✅ **OCI Images**: Available in GHCR (see packages)
  - `talos-cozystack-spin-tailscale/talos` (gateway nodes)
  - `talos-cozystack-spin-only/talos` (compute nodes)  
  - `talos-cozystack-spin-tailscale/matchbox` (home lab only)
- ✅ **boot-to-talos**: Installs OCI images on any ARM64 base AMI

### Step 1: Verify OCI Images Available

**Images are built ✅**: GitHub Actions has created the necessary OCI images

```bash
# Verify images exist in GHCR
docker pull ghcr.io/urmanac/talos-cozystack-spin-tailscale/talos:latest
docker pull ghcr.io/urmanac/talos-cozystack-spin-only/talos:latest
```

**boot-to-talos workflow**:
1. Launch EC2 with any ARM64 base AMI (Amazon Linux 2023)
2. User-data downloads boot-to-talos binary
3. boot-to-talos pulls OCI image from GHCR
4. Installs to /dev/xvda with static IP kernel args
5. Reboots into custom Talos (no AMI management!)

### Test-Driven Generation Approach

**Phase 1**: Single-node test to find breaking points
- Deploy one ARM64 instance with spin-tailscale image
- Attempt CozyStack installation 
- **Expected failure**: Insufficient RAM/disk for all Helm releases
- **Document blockers**: RAM, disk, virtualization support on ARM64
- **Bill hourly while testing**: Document on unpaid time afterward

**Phase 2**: Scale or optimize based on Phase 1 results
- Either: Add more/larger nodes 
- Or: "I have a plan" (user's solution TBD)

### Claude Desktop Instructions

**Your role**: Create AWS resources following this script, test the scenario, report results

**Reporting format**: 
```
TEST RESULTS - Single Node ARM64 CozyStack
===========================================
✅ Infrastructure: Created successfully
✅ Netboot: ARM64 Talos booted from matchbox  
❌ CozyStack install: Failed - insufficient RAM (X GB needed, Y GB available)
❌ Virtualization: ARM64 support unclear/failing
✅ SpinKube: WASM modules work fine on ARM64
💰 Cost: $X.XX for Y.YY hours

RECOMMENDED: Scale to Z nodes with AA GB RAM each
or 
ALTERNATIVE: [User's plan implementation]
```

## 📋 Infrastructure Requirements (Terraform - Persistent)

### 1. **VPC Network Configuration (Dumb Layer)**
```hcl
# Disable AWS VPC DHCP - dnsmasq on bastion handles all DHCP services
resource "aws_vpc_dhcp_options" "cozystack_disabled_dhcp" {
  # Disable AWS DHCP services entirely - VPC acts as dumb switch/router
  domain_name_servers = []
  ntp_servers        = []
  
  tags = {
    Name = "cozystack-disabled-dhcp"
    Note = "DHCP handled by dnsmasq on bastion following CozyStack patterns"
  }
}

resource "aws_vpc_dhcp_options_association" "cozystack_dhcp_disable" {
  vpc_id          = var.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.cozystack_disabled_dhcp.id
}

resource "aws_security_group" "talos_netboot" {
  name_description = "ARM64 Talos netboot - FAIL CLOSED"
  vpc_id          = var.vpc_id
  
  # DHCP, TFTP, HTTP for netboot (from subnet only)
  ingress {
    from_port   = 67
    to_port     = 68
    protocol    = "udp"
    cidr_blocks = ["10.20.13.0/24"]
    description = "DHCP for PXE boot"
  }
  
  ingress {
    from_port   = 69
    to_port     = 69  
    protocol    = "udp"
    cidr_blocks = ["10.20.13.0/24"]
    description = "TFTP for PXE boot"
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["10.20.13.0/24"]
    description = "Matchbox + asset server"
  }
  
  # Kubernetes API (6443) + Talos API (50000) - NO PUBLIC ACCESS INITIALLY
  # These will be accessible only through Tailscale after node joins network
  
  # NO IPv6 INGRESS INITIALLY - will be added via separate procedure
  # User will provide home IPv6 address for controlled access
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic allowed"
  }
  
  tags = {
    Name = "talos-netboot-fail-closed"
    Note = "Starts locked down - IPv6 access added separately"
  }
}

resource "aws_subnet" "talos_cluster" {
  vpc_id                  = var.vpc_id
  cidr_block              = "10.20.13.0/24"
  availability_zone       = "eu-west-1a" 
  map_public_ip_on_launch = false
  
  tags = {
    Name = "talos-cluster-private"
    Type = "private"
    Note = "Tailscale-only access, no public exposure"
  }
}
```

### 2. **IAM Resources for Talos Nodes**
```hcl
resource "aws_iam_role" "talos_node" {
  name = "talos-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "talos_node" {
  name = "talos-node-profile"
  role = aws_iam_role.talos_node.name
}

# Minimal permissions for cluster formation
resource "aws_iam_role_policy" "talos_cluster_formation" {
  name = "TalosClusterFormation"
  role = aws_iam_role.talos_node.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceAttribute"
        ]
        Resource = "*"
      }
    ]
  })
}
```

## 🏗️ Application Services (Bastion Host - Daily Setup)

**Location**: New repository or extension of existing automation  
**Execution**: Bastion startup script (OpenTofu + containers)  
**Timing**: After bastion starts, before evening shutdown  

### Container Stack on Bastion (10.20.13.140)

```bash
#!/bin/bash
# /opt/talos-netboot/setup-netboot-services.sh
# Following CozyStack PXE documentation adapted for ARM64
# Source: https://cozystack.io/docs/install/talos/pxe/

set -euo pipefail

# Create netboot directory structure (following CozyStack patterns)
mkdir -p /opt/talos-netboot/{matchbox,dnsmasq,nginx,tftp}

# 1. DHCP Server (dnsmasq) - Following CozyStack PXE patterns
docker run -d \
  --name talos-dhcp \
  --net host \
  --cap-add NET_ADMIN \
  -v /opt/talos-netboot/dnsmasq:/etc/dnsmasq.d \
  quay.io/poseidon/dnsmasq:latest \
  --interface=eth0 \
  --bind-interfaces \
  --dhcp-range=10.20.13.200,10.20.13.250,12h \
  --dhcp-boot=undionly.kpxe,10.20.13.140 \
  --enable-tftp \
  --tftp-root=/opt/talos-netboot/tftp \
  --dhcp-userclass=set:ipxe,iPXE \
  --dhcp-boot=tag:ipxe,http://10.20.13.140:8080/boot.ipxe \
  --dhcp-option=option:ntp-server,169.254.169.123 \
  --dhcp-option=option:domain-name,talos.local \
  --dhcp-option=option:dns-server,10.20.13.140

# 2. Matchbox (PXE boot profiles) - CozyStack standard approach
docker run -d \
  --name talos-matchbox \
  -p 8080:8080 \
  -v /opt/talos-netboot/matchbox:/var/lib/matchbox \
  quay.io/poseidon/matchbox:latest \
  -address=0.0.0.0:8080 \
  -log-level=debug

# 3. Asset Server (Talos images) - Serve kernel/initramfs
docker run -d \
  --name talos-assets \
  -p 8081:80 \
  -v /opt/talos-netboot/assets:/usr/share/nginx/html \
  nginx:alpine

# Download ARM64 Talos assets from our registry
mkdir -p /opt/talos-netboot/assets/talos/arm64

# Use current unified image (contains Spin + Tailscale extensions)
# Later: switch to spin-only image for multi-node, use Talm for Tailscale config
CONTAINER_ID=$(docker create ghcr.io/urmanac/talos-cozystack-demo:latest)
docker cp $CONTAINER_ID:/usr/install/arm64/vmlinuz /opt/talos-netboot/assets/talos/arm64/
docker cp $CONTAINER_ID:/usr/install/arm64/initramfs.xz /opt/talos-netboot/assets/talos/arm64/
docker rm $CONTAINER_ID

# 4. Configure Matchbox profiles for ARM64 Talos (adapted from CozyStack docs)
cat > /opt/talos-netboot/matchbox/profiles/arm64-single.json << EOF
{
  "id": "arm64-single",
  "name": "ARM64 Talos Single Node",
  "boot": {
    "kernel": "http://10.20.13.140:8081/talos/arm64/vmlinuz",
    "initrd": ["http://10.20.13.140:8081/talos/arm64/initramfs.xz"],
    "args": [
      "talos.platform=metal", 
      "init_on_alloc=1", 
      "slab_nomerge", 
      "pti=on",
      "console=tty0",
      "console=ttyAMA0"
    ]
  },
  "ignition_id": "arm64-single.yaml"
}
EOF

cat > /opt/talos-netboot/matchbox/groups/default.json << EOF
{
  "id": "default",
  "name": "Default ARM64 Single Node", 
  "profile": "arm64-single"
}
EOF

# Create basic boot.ipxe for ARM64
cat > /opt/talos-netboot/matchbox/assets/boot.ipxe << EOF
#!ipxe
kernel http://10.20.13.140:8081/talos/arm64/vmlinuz talos.platform=metal init_on_alloc=1 slab_nomerge pti=on console=tty0 console=ttyAMA0
initrd http://10.20.13.140:8081/talos/arm64/initramfs.xz
boot
EOF

echo "ARM64 Talos netboot services started on bastion $(hostname -I)"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Health Check Script
```bash
#!/bin/bash
# /opt/talos-netboot/health-check.sh

echo "=== ARM64 Talos Netboot Service Health ==="
for service in talos-dhcp talos-matchbox talos-assets; do
  if docker ps | grep -q $service; then
    echo "✅ $service: Running"
  else
    echo "❌ $service: Failed"
    exit 1
  fi
done

echo "🌐 Netboot endpoints:"
echo "  DHCP: 10.20.13.140:67"  
echo "  Matchbox: http://10.20.13.140:8080"
echo "  Assets: http://10.20.13.140:8081"
echo "  Boot Profile: http://10.20.13.140:8080/boot.ipxe"

echo "🔐 Security Status: FAIL-CLOSED (no external access configured)"
```

### Tailscale Configuration (for single-node after boot)
```bash
#!/bin/bash
# /opt/talos-netboot/configure-tailscale.sh
# Run this from bastion to configure Tailscale on the single node

# Tailscale configuration variables (redacted in repo)
export TS_AUTHKEY="tskey-auth-REDACTED"           # Provided at runtime
export TS_ROUTES="10.20.13.0/24"                 # Subnet to expose via Tailscale
export TS_USERSPACE="true"                       # Use userspace networking

# Apply Tailscale configuration to single node via Talm
# This makes the cluster accessible through Tailscale network
# Reference: https://github.com/kingdonb/cozystack-talm-demo/blob/main/configs/tailscale-config.yaml

echo "Manual step: Apply Tailscale config to node via 'make tailscale'"
echo "TS_AUTHKEY must be provided securely (not committed to repo)"
echo "After configuration, cluster will be accessible through Tailscale VPN"
```

### IPv6 Security Group Update Procedure
```bash
#!/bin/bash  
# /opt/talos-netboot/add-home-access.sh
# Run when ready to add controlled IPv6 access

HOME_IPV6="$1"  # Provided by user when ready

if [ -z "$HOME_IPV6" ]; then
  echo "Usage: $0 <home-ipv6-address>"
  echo "Example: $0 2001:db8::/64"
  exit 1
fi

# Add controlled access from home network to cluster
aws ec2 authorize-security-group-ingress \
  --region eu-west-1 \
  --group-name talos-netboot-fail-closed \
  --protocol tcp \
  --port 6443 \
  --source-group "$HOME_IPV6" \
  --rule-description "Kubernetes API from home"

aws ec2 authorize-security-group-ingress \
  --region eu-west-1 \
  --group-name talos-netboot-fail-closed \
  --protocol tcp \
  --port 50000 \
  --source-group "$HOME_IPV6" \
  --rule-description "Talos API from home"

echo "✅ Added home network access for $HOME_IPV6"
echo "🔐 Kubernetes API (6443) and Talos API (50000) now accessible from home"
```

## 🎮 Manual Testing Commands

**For when Claude Desktop conversation limits are reached:**

```bash
# 1. Create test ARM64 instance (t4g.nano) - FAIL CLOSED initially
aws ec2 run-instances \
  --region eu-west-1 \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t4g.nano \
  --subnet-id subnet-XXX \
  --security-group-ids sg-XXX \
  --iam-instance-profile Name=talos-node-profile \
  --user-data "#!/bin/bash\necho 'ARM64 Talos node for netboot testing'"

# 2. Verify all traffic blocked (should fail initially)
curl -m 5 http://TALOS_NODE_IP:6443 || echo "✅ Confirmed: traffic blocked"

# 3. Check netboot services on bastion  
ssh bastion "/opt/talos-netboot/health-check.sh"

# 4. Test DHCP allocation
ssh bastion "tail -f /var/log/dnsmasq.log"

# 5. Add home IPv6 access (when ready)
ssh bastion "/opt/talos-netboot/add-home-access.sh YOUR_IPV6_HERE"

# 6. Configure Tailscale (manual step with auth key)
# ssh bastion "/opt/talos-netboot/configure-tailscale.sh"
# Apply via: make tailscale (from appropriate location)

# 7. Emergency cleanup
aws ec2 describe-instances \
  --region eu-west-1 \
  --filters "Name=tag:Project,Values=talos-arm64" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text | xargs aws ec2 terminate-instances --region eu-west-1 --instance-ids

# 8. Check costs
aws ce get-cost-and-usage \
  --region eu-west-1 \
  --time-period Start=2025-11-18,End=2025-11-19 \
  --granularity DAILY \
  --metrics BlendedCost
```

## 💰 Cost Controls

- **t4g.nano**: $0.0042/hour (free tier eligible)
- **Max instances**: 3 ARM64 nodes (experimental cluster)
- **Daily budget**: <$0.50 for experiments
- **Auto-shutdown**: Bastion ASG terminates daily, containers stop

## 🚦 Success Criteria

1. **Infrastructure**: Terraform applies without errors, fail-closed networking ready
2. **Security**: All external traffic blocked initially, only internal subnet communication
3. **Services**: All 3 containers running on bastion, health check passes  
4. **DHCP**: Test instance gets IP in 10.20.13.200-250 range
5. **PXE**: ARM64 instance can fetch boot profile and kernel from matchbox
6. **Tailscale**: Single node can be configured for VPN access to cluster
7. **Controlled Access**: IPv6 procedure works for adding home network access

## 🔗 Integration Points & References

- **Existing**: Bastion ASG, VPC, IAM roles from aws-accounts repo
- **New**: Talos-specific networking and fail-closed security groups
- **Home Access**: Requires IPv6 address for security group (provided when ready)
- **Asset Pipeline**: GHCR unified image (ghcr.io/urmanac/talos-cozystack-demo:latest)
- **CozyStack Docs**: https://cozystack.io/docs/install/talos/pxe/
- **Tailscale Config**: https://github.com/kingdonb/cozystack-talm-demo/blob/main/configs/tailscale-config.yaml

### Related Repositories (Reference)
- **aws-accounts**: https://github.com/urmanac/aws-accounts (Terraform modules)
- **moonlander**: https://github.com/kingdon-ci/moonlander (WIP - cluster secrets management)  
- **kubeconfig-ca-fetch**: https://github.com/kingdon-ci/kubeconfig-ca-fetch (OIDC cluster access)

---

**Claude Desktop**: Execute terraform first (persistent infrastructure with fail-closed security), then implement bastion container stack. Test with locked-down networking first, then controlled access procedures.