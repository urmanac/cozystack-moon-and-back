# CozyStack on AWS: "Third Death Star" Design Document

## Context for Claude Agent

You are helping to design and implement a home lab replica in AWS, targeting ARM64 architecture with Talos Linux netbooting and CozyStack orchestration. The goal is to validate this stack in the cloud before deploying to Raspberry Pi CM3 modules at home, while staying within AWS free tier limits.

## Project Goals

1. **Replicate home lab topology** in AWS using 10.20.x.x addressing
2. **Stay within free tier** - target $0.00-0.08/month (EBS only)
3. **ARM64 first** - validate for eventual Raspberry Pi deployment
4. **Zero GDPR risk** - private networking only, no public services yet
5. **Netboot Talos nodes** from bastion-hosted Docker infrastructure
6. **Run CozyStack** on 1-3 t4g instances as needed for experiments

## Home Lab Current State (Reference)

```
Internet → DD-WRT (10.17.12.1)
           └─ 10.17.12.0/24 (front subnet, NAT'd, DHCP from DD-WRT)
              └─ Mikrotik (10.17.12.249/10.17.13.249) - dual-homed router
                 └─ 10.17.13.0/24 (inner subnet, own DNS/DHCP)
                    ├─ 10.17.13.140 - fileserver running netboot infrastructure:
                    │  ├─ dnsmasq (DHCP only)
                    │  ├─ matchbox (PXE boot server)
                    │  ├─ 5x registry:2 (pull-through caches)
                    │  └─ pihole (DNS for entire network)
                    └─ Talos nodes (netbooting, running CozyStack)
```

**Key characteristics:**
- No encryption needed on private network (trust boundary at router)
- DNS served from 10.17.13.140, used by all devices including front subnet
- Pull-through registry caches for: docker.io, gcr.io, ghcr.io, quay.io, registry.k8s.io
- Talos nodes use matchbox for netboot, get config via pull-through cache
- IPv6 link-local only, not routed to public internet

## AWS Target Architecture

### Network Topology

```
VPC: 10.20.0.0/16 (eu-west-1)
│
├─ Public Subnet: 10.20.1.0/24 (eu-west-1a)
│  └─ Internet Gateway attached
│  └─ NAT Gateway (for private subnet egress)
│  └─ [Future: Mikrotik router VM via KubeVirt]
│
└─ Private Subnet: 10.20.13.0/24 (eu-west-1a)
   ├─ Route: 0.0.0.0/0 → NAT Gateway in public subnet
   ├─ Route: 10.20.1.0/24 → local (VPC routing)
   │
   ├─ Bastion Host (t4g.small, scheduled 5hrs/day via ASG)
   │  ├─ Role: Netboot infrastructure + SSH access + pi-hole DNS
   │  ├─ Docker containers:
   │  │  ├─ dnsmasq (DHCP for 10.20.13.0/24)
   │  │  ├─ matchbox (PXE boot server)
   │  │  ├─ registry:2 x5 (pull-through caches)
   │  │  └─ pihole (DNS for entire VPC)
   │  ├─ Static private IP: 10.20.13.140
   │  └─ Security: SSH from specific IPv6 home address only
   │
   └─ Talos Nodes (t4g.small, manual on-demand only)
      ├─ Count: 1-3 instances (budget: 610 free tier hours/month remaining)
      ├─ Netboot from bastion's matchbox server
      ├─ Running CozyStack on ARM64
      ├─ Default-deny security group
      └─ Access: Only via talosctl from authorized operators
```

### IPv6 Strategy

- **Phase 1 (now)**: Private IPv4 only, no IPv6 routing
- **Phase 2 (future)**: Dual-stack VPC (IPv4 private + IPv6 public/internal)
- **Rationale**: Zero GDPR risk during development, add IPv6 when ready for external services

### Security Group Architecture

1. **bastion-sg** (attached to bastion in private subnet)
   - Ingress: SSH (22) from home IPv6 address only
   - Ingress: All traffic from talos-nodes-sg (for netboot services)
   - Egress: All traffic (for package updates, registry pulls)

2. **talos-nodes-sg** (attached to Talos instances)
   - Ingress: All traffic from bastion-sg (for netboot, management)
   - Ingress: Inter-node traffic from talos-nodes-sg (for K8s)
   - Egress: All traffic to bastion-sg (for netboot, registry)
   - Egress: HTTPS to NAT Gateway (for initial setup only)

3. **[Future] mikrotik-sg** (for router VM in public subnet)
   - Ingress: Traffic from private subnet
   - Egress: Routing to both subnets

### Free Tier Budget Management

**Current state:**
- 1x bastion (t4g.small): ~5 hrs/day = 150 hrs/month
- Free tier limit: 750 hrs/month total across all t4g instances until December 2025

**Experiment budget:**
- Remaining: 600 hrs/month for Talos nodes
- 3 nodes scenario: 200 hrs/month each = ~6.5 hrs/day each
- OR: Run experiments in 2-3 hour windows, terminate immediately after

**Cost targets:**
- EBS: ~$0.03-0.08/month (gp3 volumes during runtime)
- Compute: $0.00 (stay under free tier)
- Data transfer: $0.00 (private networking + free tier egress)
- **Total: < $0.10/month**

## Technical Implementation Details

### Bastion Configuration

**User data script additions:**
```bash
# Install Docker (already present)
# Install opentofu via wireguard bridge (already working)

# Static IP assignment via ENI or launch template
# Create /opt/netboot directory structure
# Pull and start Docker containers:
#   - dnsmasq:v0.5.0-40-g494d4e0
#   - matchbox:v1.10.5-cozy-spin-tailscale (custom build)
#   - registry:2 (5 instances on ports 5050-5054)
#   - pihole:2024.07.0

# Configure dnsmasq for DHCP on 10.20.13.0/24
# Configure matchbox with Talos boot images from CozyStack
# Configure VPC DHCP options to use bastion as DNS server
```

**ENI Configuration:**
- Primary ENI in private subnet (10.20.13.140)
- Secondary ENI considerations: Not needed initially, bastion is single-homed
- Future dual-homing: Add ENI in public subnet when Mikrotik router moves to KubeVirt

### Talos Node Netboot Process

1. Instance launches in private subnet with PXE boot enabled
2. DHCP request → dnsmasq on bastion (10.20.13.140)
3. DHCP response includes next-server (matchbox) and boot filename
4. PXE boot → matchbox serves Talos kernel/initrd
5. Talos boots, pulls config from matchbox
6. Talos pulls images via registry pull-through caches on bastion
7. Node joins cluster, CozyStack manages from there

### CozyStack Bootstrap

**First node:**
```bash
# From operator workstation via SSH to bastion, then talosctl:
talosctl bootstrap --nodes 10.20.13.x
# CozyStack init process (TBD - follow CozyStack docs)
```

**Additional nodes:**
- Join cluster automatically via CozyStack orchestration
- Or manual join via talosctl if needed

### DNS Strategy

**Phase 1: Pi-hole on bastion**
- Pi-hole container serves DNS for entire VPC
- VPC DHCP options point to 10.20.13.140
- Upstream DNS: AWS DNS (10.20.0.2) or public resolvers

**Phase 2: Redundant DNS (future)**
- Second pi-hole instance in public subnet (or separate t4g.nano)
- Both configured via Terraform
- VPC DHCP options: primary 10.20.13.140, secondary 10.20.1.x

**Phase 3: Lambda DNS (experiment)**
- Evaluate AWS Lambda for DNS serving
- Compare cost vs. t4g.nano scheduled instance
- Likely overkill for private network needs

### Terraform Structure

**Existing modules (reuse):**
- VPC with subnets
- Security groups
- ASG for bastion (scheduled start/stop)
- IAM roles for instances

**New additions needed:**
- Private subnet (10.20.13.0/24)
- NAT Gateway in public subnet
- Additional security groups (talos-nodes-sg)
- Launch template for Talos nodes (manual launch only, no ASG)
- ENI for bastion static IP
- VPC DHCP options (point to bastion DNS)
- Docker container orchestration on bastion (user data)

**Terraform state management:**
- Currently using local state
- Consider: Instance self-management via IAM role + S3 backend
- Or: Keep it simple, manage from workstation via SSH tunnel

### Termination Procedure (Return to $0.00)

1. Terminate all Talos node instances (manual)
2. Let bastion ASG schedule naturally shut down after 5-hour window
3. Verify no running instances: `aws ec2 describe-instances --filters Name=instance-state-name,Values=running`
4. Cost check: EBS volumes should be only remaining cost (~$0.03/month)
5. Optional: Delete EBS volumes if true zero desired (lose data)

## Implementation Phases

### Phase 0: Design & Planning (NOW)
- [x] Document network topology
- [x] Calculate free tier budget
- [ ] Review with operator, get approval

### Phase 1: Network Foundation
- [ ] Create VPC (10.20.0.0/16)
- [ ] Create subnets (public 10.20.1.0/24, private 10.20.13.0/24)
- [ ] Create Internet Gateway
- [ ] Create NAT Gateway in public subnet
- [ ] Configure route tables
- [ ] Create security groups (bastion-sg, talos-nodes-sg)
- [ ] Update VPC DHCP options (point to future bastion DNS)

### Phase 2: Bastion Infrastructure
- [ ] Modify existing bastion ASG/launch template:
  - [ ] Move to private subnet (10.20.13.0/24)
  - [ ] Assign static IP (10.20.13.140) via ENI
  - [ ] Update security group to allow SSH from home IPv6
  - [ ] Add user data for Docker container orchestration
- [ ] Deploy and test netboot containers:
  - [ ] dnsmasq (DHCP test)
  - [ ] matchbox (serve Talos images)
  - [ ] registry pull-through caches
  - [ ] pi-hole (DNS test from VPC)
- [ ] Verify bastion scheduled start/stop still works

### Phase 3: Talos Node Deployment
- [ ] Create Talos node launch template (t4g.small, no ASG)
- [ ] Manually launch first Talos node
- [ ] Verify netboot process:
  - [ ] DHCP lease from dnsmasq
  - [ ] PXE boot from matchbox
  - [ ] Talos boots successfully
- [ ] Bootstrap CozyStack cluster
- [ ] Add 2nd and 3rd nodes as budget allows

### Phase 4: CozyStack Validation
- [ ] Deploy test workload (SpinKube demo?)
- [ ] Verify KubeVirt capabilities
- [ ] Test virtual machine creation (future Mikrotik router)
- [ ] Measure performance vs. home lab
- [ ] Document customizations (Talos extensions: Tailscale, Spin)

### Phase 5: Cost Monitoring & Optimization
- [ ] Track daily costs via AWS Cost Explorer
- [ ] Verify free tier usage under limits
- [ ] Optimize EBS volume sizes if needed
- [ ] Document experiment runtime costs
- [ ] Prepare talk demo & slides

## Open Questions & Future Work

1. **Dual-homing bastion**: How to replicate 10.17.12.109/10.17.13.254 pattern?
   - Answer: Multiple ENIs on bastion, one in each subnet
   - Cost: Free for first ENI, minimal for second
   - Timing: Implement when adding Mikrotik router VM

2. **Mikrotik router in KubeVirt**: Is this necessary initially?
   - Answer: No, use native VPC routing first
   - Future: Deploy as VM for high-fidelity home lab replication

3. **IPv6 dual-stack**: When to enable?
   - Answer: After private networking validated
   - Prerequisites: GDPR compliance plan, security audit

4. **Tailscale integration**: Where to run it?
   - Bastion: Yes, for operator access
   - Talos nodes: Yes, baked into custom Talos image
   - Timing: After basic netboot working

5. **Registry pull-through cache sizing**: How much storage needed?
   - Answer: Monitor during experiments, likely < 20GB total
   - EBS volume on bastion or separate EBS attached to bastion

6. **Terraform state management**: Self-managing infrastructure?
   - Answer: Start simple (local state), migrate to S3 if needed
   - Instance IAM role already permits S3 access for future

## Success Criteria

- [ ] Talos nodes successfully netboot from bastion in < 5 minutes
- [ ] CozyStack cluster operational with 1-3 nodes
- [ ] SpinKube workload deploys and runs on ARM64
- [ ] Monthly cost remains under $0.10 (EBS only)
- [ ] Can terminate all instances and return to near-$0.00 state
- [ ] Talk demo ready: "Home Lab to the Moon and Back"
- [ ] Infrastructure can be replicated at home on Raspberry Pi

## Cost Projection for 3-Node Experiment

**Scenario: 3-hour experiment session**
- 3x t4g.small instances: 9 instance-hours (free tier)
- 3x 8GB gp3 volumes for 3 hours: ~$0.001
- Bastion running: 3 hours (free tier, part of daily 5hr schedule)
- Data transfer: $0.00 (private networking)
- **Total session cost: < $0.01**

**Scenario: 5 experiment sessions per week, 4 weeks**
- 20 sessions x $0.01 = $0.20
- Bastion scheduled cost: $0.04/month (EBS while running)
- **Total monthly experiment cost: ~$0.24**

**Staying under $0.10/month:**
- Reduce experiment frequency to 2-3 sessions/week
- Shorten sessions to 2 hours
- Delete EBS volumes between sessions (lose data, re-netboot each time)

## References & Resources

- Talos Linux netboot guide: https://www.talos.dev/v1.x/talos-guides/install/bare-metal-platforms/pxe/
- CozyStack documentation: https://cozystack.io/docs/
- Matchbox server: https://github.com/poseidon/matchbox
- Home lab "Cozystack Speed Run" YouTube channel (reference for replication)
- AWS t4g free tier: https://aws.amazon.com/ec2/instance-types/t4g/
- Conference talk abstract: "Home Lab to the Moon and Back" (context for demo)

## Next Steps for Claude Agent

When operator returns, be prepared to:

1. **Review this design** - answer questions, revise as needed
2. **Generate Terraform code** - start with VPC and network foundation
3. **Create user data scripts** - Docker container orchestration for bastion
4. **Provide cost monitoring queries** - AWS CLI commands for tracking spend
5. **Document netboot process** - step-by-step validation checklist
6. **Troubleshooting guide** - common issues and solutions

Operator is going to breakfast with spouse. Save this document for reference. When they return, start with: "Welcome back! Ready to build the Third Death Star?"

---

*Document created: 2025-11-16*  
*Target completion: Before December 2025 (when t4g free tier expires)*  
*For: Talk "Home Lab to the Moon and Back" at [Conference TBD]*
