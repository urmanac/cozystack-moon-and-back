# Claude Desktop Session 4 - Infrastructure Automation Context

## Mission Overview

**Objective**: Execute ARM64 CozyStack deployment on AWS with role-based agent delegation
**Timeline**: December 3rd CozySummit demo preparation
**Context Limit**: High efficiency required due to token constraints

## Previous Session Analysis

### Claude Desktop Strengths Demonstrated ✅
- **Documentation Comprehension**: Correctly parsed deployment guides and identified workflow
- **Gap Analysis**: Precisely identified critical blockers (VPC IDs, Talos image paths, session tokens)
- **Tool Understanding**: Accurately assessed available MCP capabilities
- **Strategic Thinking**: Recognized infrastructure → testing → cleanup progression

### Identified Blockers from Session 3
1. **VPC/Subnet IDs**: Placeholder values need real infrastructure references
2. **Target Region**: Alignment between docs (us-west-2) vs AWS MCP default (eu-west-1)
3. **Custom Talos Image**: Specific GHCR path for `ghcr.io/your-org/talos:v1.10.5-cozy-spin`
4. **Bastion Registry Cache**: Pre-deployment configuration status
5. **AWS Session Token**: MFA refresh required

## Role-Based Delegation Strategy

### Stakpak Agent Role: Infrastructure Foundation
**Strengths**: Terraform expertise, cloud resource management, persistent state handling
**Responsibilities**:
- [ ] Update `aws-accounts` repo Terraform configurations
- [ ] Add bastion host static IP allocation in VPC
- [ ] Configure bastion user-data for OCI registry cache
- [ ] Update security groups for registry cache access (port 5000)
- [ ] Prepare Terraform plan for infrastructure changes
- [ ] Provide real VPC/subnet IDs for Claude Desktop consumption

**Stakpak Deliverables**:
```bash
# Expected outputs for Claude Desktop
terraform plan -out=bastion-updates.tfplan
# Real VPC/subnet IDs in terraform.tfstate
# Bastion host configuration with registry cache
# Security group updates for port 5000 access
```

### Claude Desktop Role: Automation and Deployment
**Strengths**: AWS API automation, script generation, testing orchestration
**Responsibilities**:
- [ ] Consume infrastructure outputs from Stakpak
- [ ] Execute EC2 instance creation with real VPC parameters
- [ ] Orchestrate boot-to-Talos deployment process
- [ ] Validate cluster deployment and CozyStack installation
- [ ] Execute Crossplane v2 testing workflows
- [ ] Generate cleanup/teardown documentation

**Claude Desktop Inputs Required**:
```yaml
# From Stakpak infrastructure work
vpc_id: "vpc-real-id-from-terraform"
subnet_ids:
  control_plane_1: "subnet-real-cp1-id"
  control_plane_2: "subnet-real-cp2-id" 
  worker_subnet: "subnet-real-worker-id"
bastion_ip: "10.0.1.100"  # Static IP from Terraform
registry_cache_endpoint: "10.0.1.100:5000"
region: "us-west-2"  # Aligned with documentation
```

## Infrastructure Prerequisites (Stakpak Tasks)

### 1. Bastion Host Enhancement
**Current State**: Basic bastion host in `aws-accounts` repo
**Required Updates**:
```hcl
# terraform/bastion.tf updates needed
resource "aws_instance" "bastion" {
  # Add static private IP
  private_ip = "10.0.1.100"
  
  # Enhanced user data for registry cache
  user_data = base64encode(templatefile("${path.module}/bastion-userdata.sh", {
    registry_cache_port = 5000
    ghcr_proxy_config = true
  }))
}

# New security group rules
resource "aws_security_group_rule" "bastion_registry_cache" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.bastion.id
}
```

### 2. Registry Cache Configuration
**Bastion User Data Script**:
```bash
#!/bin/bash
# bastion-userdata.sh - OCI pull-through cache setup

# Install Docker
apt-get update
apt-get install -y docker.io

# Configure registry cache for GHCR
mkdir -p /opt/registry-config
cat > /opt/registry-config/config.yml << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
proxy:
  remoteurl: https://ghcr.io
  username: ${GHCR_USERNAME}
  password: ${GHCR_TOKEN}
EOF

# Start registry cache
docker run -d \
  --name registry-cache \
  --restart=always \
  -p 5000:5000 \
  -v /opt/registry-config:/etc/docker/registry \
  -v /opt/registry-data:/var/lib/registry \
  registry:2

echo "Registry cache started on port 5000"
```

### 3. VPC Parameter Export
**Required Terraform Outputs**:
```hcl
# outputs.tf additions
output "cozystack_infrastructure" {
  description = "Infrastructure parameters for CozyStack deployment"
  value = {
    vpc_id = aws_vpc.main.id
    region = var.aws_region
    subnets = {
      control_plane_1 = aws_subnet.control_plane_1.id
      control_plane_2 = aws_subnet.control_plane_2.id
      worker_subnet   = aws_subnet.worker.id
    }
    bastion = {
      instance_id = aws_instance.bastion.id
      private_ip  = aws_instance.bastion.private_ip
      public_ip   = aws_instance.bastion.public_ip
    }
    security_groups = {
      bastion_sg = aws_security_group.bastion.id
    }
  }
}
```

## Claude Desktop Execution Plan

### Phase 1: Infrastructure Validation (5 minutes)
1. **Consume Stakpak Outputs**: Read infrastructure parameters from Terraform state
2. **Validate Prerequisites**: Confirm bastion registry cache operational
3. **Prepare Deployment Manifest**: Populate real VPC/subnet IDs in cluster-manifest.yaml

### Phase 2: Cluster Deployment (15 minutes)
1. **Execute EC2 Creation**: Use AWS MCP to create ARM64 instances
2. **Monitor Boot-to-Talos**: Validate Ubuntu → Talos transition
3. **Bootstrap Cluster**: Execute talm workflow with CozyStack preset
4. **Validate Installation**: Confirm cluster operational status

### Phase 3: Testing and Documentation (10 minutes)
1. **Execute Crossplane Tests**: Run ARM64 compatibility validation
2. **Document Progress**: Generate session summary with status
3. **Prepare Cleanup Script**: Ready teardown procedures for post-demo

## Critical Success Factors

### For Stakpak Infrastructure Work:
- [ ] Bastion host static IP configured
- [ ] Registry cache operational and accessible
- [ ] Real VPC/subnet IDs available for Claude consumption
- [ ] Security groups updated for cluster communication

### For Claude Desktop Session:
- [ ] AWS session token refreshed with MFA
- [ ] Infrastructure parameters consumed from Stakpak work
- [ ] Boot-to-Talos process successfully executed
- [ ] Deployment progress documented for teardown

## Risk Mitigation

### Context Limit Management:
- **Priority 1**: Core deployment automation
- **Priority 2**: Basic testing validation  
- **Priority 3**: Comprehensive documentation (if time permits)

### Failure Recovery:
- Stakpak handles infrastructure rollback via Terraform
- Claude Desktop generates emergency cleanup scripts
- Manual intervention points clearly documented

## Next Session Preparation

### Before 4pm Claude Desktop Session:
1. **Stakpak**: Complete infrastructure updates and provide parameters
2. **Human**: Refresh AWS session token with MFA
3. **Preparation**: Stage custom Talos image location details

### During Claude Desktop Session:
1. **Infrastructure Validation**: Confirm prerequisites met
2. **Deployment Execution**: Follow documented automation workflow
3. **Progress Documentation**: Generate cleanup and status reports

---

**Success Metrics**: 
- ARM64 CozyStack cluster operational
- Crossplane v2 basic functionality validated  
- Cleanup documentation prepared for post-demo teardown
- December 3rd demo readiness achieved

**Agent Coordination**: Stakpak handles persistent infrastructure, Claude Desktop handles ephemeral automation and testing