# AWS Infrastructure Handoff Document

## Context for AWS-Capable Claude Agent

You are receiving this handoff to implement the AWS infrastructure for the "Home Lab to the Moon and Back" demo. This document contains **complete specifications** for what needs to be built, following the Test-Driven Generation (TDG) methodology.

**Your role**: Implement AWS infrastructure to support custom ARM64 Talos netboot
**My role**: Custom Talos image building, GitHub Actions, documentation
**Budget**: Stay under $0.10/month (AWS free tier only)
**Timeline**: Demo on December 3, 2025 (12 days)

## Infrastructure Requirements (Ready to Implement)

### Network Foundation - VPC & Subnets
```
Region: eu-west-1
VPC: 10.20.0.0/16

Subnets:
├─ Public Subnet: 10.20.1.0/24 (eu-west-1a)
│  ├─ Internet Gateway attached
│  └─ NAT Gateway (for private subnet egress)
│
└─ Private Subnet: 10.20.13.0/24 (eu-west-1a)  
   ├─ Route: 0.0.0.0/0 → NAT Gateway
   ├─ Route: 10.20.1.0/24 → local
   └─ Default subnet for all instances
```

### Security Groups
```yaml
bastion-sg:
  ingress:
    - protocol: tcp
      port: 22
      source: ${HOME_IPV6}/128  # Operator's home IPv6
    - protocol: all
      source: talos-nodes-sg    # From Talos nodes
  egress:
    - protocol: all
      destination: 0.0.0.0/0    # Internet access

talos-nodes-sg:
  ingress:
    - protocol: all
      source: bastion-sg        # From bastion
    - protocol: all  
      source: talos-nodes-sg    # Inter-node traffic
  egress:
    - protocol: all
      destination: bastion-sg   # To bastion
    - protocol: tcp
      port: 443
      destination: 0.0.0.0/0    # HTTPS only for initial setup
```

### Bastion Host Configuration

**Instance**: Existing ASG (modify, don't recreate)
- **Type**: t4g.small (ARM64)
- **Schedule**: 5 hours/day via ASG schedule (keep existing)
- **Subnet**: MOVE from public to private: 10.20.13.0/24  
- **Static IP**: 10.20.13.140 (via ENI)
- **Security Group**: bastion-sg (update existing)

**User Data Additions** (append to existing):
```bash
#!/bin/bash
# Existing user data remains unchanged
# ADD these sections:

# Install container dependencies
apt-get update && apt-get install -y docker.io docker-compose

# Create matchbox directory structure
mkdir -p /opt/matchbox/{assets,profiles,groups,ignition}
mkdir -p /opt/bastion-setup

# Create asset extraction script
cat > /opt/bastion-setup/extract-talos-assets.sh << 'EOF'
#!/bin/bash
set -e
echo "Pulling custom Talos ARM64 image from GHCR..."
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable

echo "Extracting ARM64 boot assets..."
mkdir -p /opt/matchbox/assets/talos/arm64
docker run --rm \
  -v /opt/matchbox/assets:/output \
  ghcr.io/urmanac/talos-cozystack-demo:demo-stable \
  /output/talos/arm64/

echo "Setting permissions..."
chown -R 1000:1000 /opt/matchbox/assets/
chmod -R 644 /opt/matchbox/assets/talos/arm64/*

echo "✅ Custom ARM64 Talos assets ready"
ls -la /opt/matchbox/assets/talos/arm64/
EOF
chmod +x /opt/bastion-setup/extract-talos-assets.sh

# Run initial asset extraction
/opt/bastion-setup/extract-talos-assets.sh

# Start Docker containers (see docker-compose.yml section)
cd /opt/bastion-setup && docker-compose up -d
```

**Docker Compose Configuration**:
```yaml
# /opt/bastion-setup/docker-compose.yml
version: '3.8'
services:
  dnsmasq:
    image: dnsmasq/dnsmasq:latest
    container_name: dnsmasq
    restart: unless-stopped
    ports:
      - "67:67/udp"
      - "69:69/udp" 
    volumes:
      - ./dnsmasq.conf:/etc/dnsmasq.conf:ro
      - /opt/matchbox/assets:/var/lib/matchbox/assets:ro
    cap_add:
      - NET_ADMIN
    network_mode: host

  matchbox:
    image: quay.io/poseidon/matchbox:v0.11.0
    container_name: matchbox
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "8081:8081"
    volumes:
      - /opt/matchbox:/var/lib/matchbox:Z
    environment:
      MATCHBOX_ADDRESS: "0.0.0.0:8080"
      MATCHBOX_RPC_ADDRESS: "0.0.0.0:8081"
    network_mode: host

  registry-docker-io:
    image: registry:2
    container_name: registry-docker-io
    restart: unless-stopped
    ports:
      - "5050:5000"
    environment:
      REGISTRY_PROXY_REMOTEURL: https://registry-1.docker.io
    network_mode: host

  # Add 4 more registry caches for gcr.io, ghcr.io, quay.io, registry.k8s.io
  # (Similar configuration, ports 5051-5054)

  pihole:
    image: pihole/pihole:2024.07.0
    container_name: pihole
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
    environment:
      TZ: 'UTC'
      WEBPASSWORD: 'cozystack-demo'
    volumes:
      - pihole_etc:/etc/pihole
      - pihole_dnsmasq:/etc/dnsmasq.d
    network_mode: host

volumes:
  pihole_etc:
  pihole_dnsmasq:
```

### Talos Node Launch Template

**Purpose**: Manual launches only (no ASG)
```yaml
LaunchTemplate:
  name: cozystack-talos-arm64
  instance_type: t4g.small
  architecture: arm64
  subnet: private-subnet (10.20.13.0/24)
  security_group: talos-nodes-sg
  
  user_data: |
    #!ipxe
    # PXE boot configuration
    dhcp net0
    chain http://10.20.13.140:8080/boot.ipxe

  block_device_mappings:
    - device_name: /dev/sda1
      ebs:
        volume_type: gp3
        volume_size: 8  # GB (minimal)
        delete_on_termination: true
```

### VPC DHCP Options

**Update VPC DHCP options** to point to bastion for DNS:
```yaml
dhcp_options:
  domain_name: ec2.internal
  domain_name_servers: 
    - 10.20.13.140  # Bastion Pi-hole
    - 10.20.0.2     # AWS default (fallback)
```

## Implementation Priority

### Phase 1: Network Foundation ✅ Ready to Implement
**What**: Create VPC, subnets, IGW, NAT Gateway, security groups
**Test**: `tests/01-network-foundation.sh` (from TDG-PLAN.md)
**Expected time**: 30 minutes

### Phase 2: Bastion Migration ✅ Ready to Implement  
**What**: Move existing bastion ASG to private subnet, add ENI for static IP
**Test**: `tests/02-bastion-private-subnet.sh`
**Expected time**: 45 minutes
**⚠️ CAUTION**: Don't break existing scheduled start/stop

### Phase 3: Container Infrastructure ✅ Ready to Implement
**What**: Add Docker containers via user data, test asset extraction
**Test**: `tests/03-netboot-infrastructure.sh` 
**Expected time**: 1 hour
**Dependencies**: Custom images built (my responsibility)

### Phase 4: Launch Template ✅ Ready to Implement
**What**: Create Talos node launch template, test manual launch
**Test**: Manual instance launch, verify netboot
**Expected time**: 30 minutes

## Test-Driven Validation

I've created comprehensive tests in `tests/` directory. After each phase:

1. **Run the corresponding test**: `./tests/0X-phase-name.sh`
2. **Report results**: Pass/fail with error details
3. **If failed**: Troubleshoot and retry
4. **If passed**: Move to next phase

**Example**:
```bash
# After implementing Phase 1
./tests/01-network-foundation.sh
# Expected: ✅ All network tests pass

# After implementing Phase 2  
./tests/02-bastion-private-subnet.sh
# Expected: ✅ Bastion accessible via SSH, static IP working
```

## Critical Constraints

### Free Tier Budget Management
- **Current usage**: ~$0.04/month (bastion EBS)
- **Budget remaining**: ~$0.06/month 
- **NAT Gateway**: ~$0.04/month (within limits)
- **EBS volumes**: Monitor daily, delete after experiments
- **Compute**: 750 t4g hours/month (150 used by bastion = 600 remaining)

### Home Office Access
- **SSH access**: From specific IPv6 address only
- **Replace**: `${HOME_IPV6}` with actual operator IPv6
- **Verification**: Test SSH works before considering phase complete

### Zero Public Services
- **All instances**: Private subnet only
- **No public IPs**: Except NAT Gateway
- **No ingress**: From internet to private resources
- **DNS**: Internal only (Pi-hole on bastion)

## Expected Deliverables

### Phase 1 Outputs
- VPC ID and subnet IDs
- Security group IDs
- Route table configurations
- NAT Gateway public IP

### Phase 2 Outputs  
- Updated bastion ASG configuration
- ENI ID for static IP (10.20.13.140)
- Confirmation of SSH access from home
- Bastion schedule still working (5hrs/day)

### Phase 3 Outputs
- Docker containers running on bastion
- matchbox serving on http://10.20.13.140:8080
- Custom ARM64 assets extracted and served
- dnsmasq DHCP operational for 10.20.13.0/24

### Phase 4 Outputs
- Launch template for manual Talos node deployment
- Successfully launched test instance
- Instance receives DHCP lease from bastion
- Instance attempts PXE boot (even if Talos image not ready yet)

## Error Recovery Procedures

### If Bastion Becomes Inaccessible
1. **Check ASG**: Ensure instance running during scheduled hours
2. **Check Security Group**: Verify SSH from correct home IPv6
3. **Check Route Tables**: Private subnet should route to NAT Gateway
4. **Emergency**: Launch temporary bastion in public subnet if needed

### If Costs Exceed Budget
1. **Immediate**: Terminate all non-bastion instances  
2. **Check**: AWS Cost Explorer for unexpected charges
3. **Alert**: Stop experiment, document issue
4. **Prevention**: Set billing alerts for $0.08/month threshold

### If Tests Fail
1. **Document**: Exact error message and context
2. **Check**: AWS CloudTrail for API errors
3. **Validate**: IAM permissions for all operations
4. **Escalate**: Provide test output for debugging

## Communication Protocol

### Status Updates
**When to report**:
- ✅ Each phase complete with test results
- ⚠️ Any phase taking longer than expected time
- ❌ Any test failures with error details
- 💰 Any cost concerns or budget questions

**How to report**:
- **Success**: "Phase X complete. Test results: [pass/fail]. Next: Phase Y"
- **Issues**: "Phase X blocked. Error: [details]. Need guidance on: [specific question]"
- **Costs**: "Current spend: $X.XX/month. Projection: $Y.YY/month"

### Questions to Ask
- ✅ **Good**: "Phase 2 user data modification - should I append or replace existing script?"
- ✅ **Good**: "NAT Gateway costs $0.045/month - proceed within budget?"
- ❌ **Don't ask**: "How do I create a VPC?" (documented above)
- ❌ **Don't ask**: "Should we use Terraform?" (your choice)

## Success Criteria

After all 4 phases complete, we should have:

- [ ] **Network**: Private VPC with bastion accessible via SSH
- [ ] **Bastion**: Running netboot infrastructure (dnsmasq + matchbox)
- [ ] **Assets**: Custom ARM64 Talos images served by matchbox
- [ ] **Launch**: Ability to manually launch Talos nodes for testing
- [ ] **Costs**: Monthly projection under $0.10
- [ ] **Tests**: All TDG tests passing

## Next Steps After Infrastructure Ready

1. **My responsibility**: Finalize custom Talos image builds
2. **Joint**: Test end-to-end netboot with real Talos nodes
3. **My responsibility**: CozyStack installation and SpinKube demo
4. **Joint**: Demo script and presentation materials

---

**Ready to start?** Begin with Phase 1 (Network Foundation).

**Questions?** Ask specific implementation questions, not general design questions.

**Timeline**: Target 2-3 hours total implementation time across all phases.

**Remember**: This is a demo, not production. Simple solutions preferred over complex ones.