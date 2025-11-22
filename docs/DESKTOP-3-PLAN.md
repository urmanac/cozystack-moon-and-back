# My Understanding of the AWS ARM64 CozyStack Deployment

## Executive Summary

When AWS session tokens are authorized, I will help deploy a **CozyStack Kubernetes platform** on **ARM64 EC2 instances** in AWS. This involves creating EC2 instances that boot Ubuntu and then transition ("kexec") into custom Talos Linux images, forming a Kubernetes cluster with CozyStack installed on top.

---

## What I Understand I'll Be Doing

### Phase 1: Infrastructure Creation (AWS CLI)

1. **Dynamic AMI Lookup**
   - Find the latest Ubuntu 22.04 ARM64 AMI from Canonical (owner: `099720109477`)
   - Use filters for `arm64` architecture and `hvm-ssd` storage

2. **Security Group Creation**
   - Create security group `cozystack-cluster` in the target VPC
   - Open required ports: 6443 (K8s API), 50000 (Talos API), 2379-2380 (etcd), 10250 (kubelet), 5000 (registry cache)

3. **EC2 Instance Provisioning**
   - Create **3 control plane nodes** (c7g.large)
   - Create **2+ worker nodes** (c7g.xlarge)
   - Assign static private IPs within VPC subnets
   - Tag instances with cluster membership

4. **Boot-to-Talos Process**
   - Instances boot Ubuntu first
   - Cloud-init downloads custom Talos image from bastion registry cache
   - System kexec's into Talos (reboot without BIOS)

### Phase 2: Cluster Bootstrap (Post-Talos Boot)

1. **Talos Cluster Formation**
   - Use `talm` CLI to initialize cluster
   - Apply ARM64-specific configurations
   - Bootstrap HA control plane

2. **CozyStack Installation**
   - Install core CozyStack components
   - Configure Piraeus storage backend
   - Set up ingress and OIDC integration

### Phase 3: Testing (Crossplane v2)

1. **KubeVirt Validation** (blocking test)
   - Determine if KubeVirt works on ARM64
   - Falls back to namespace-based multi-tenancy if not

2. **Crossplane Provider Installation**
   - Install AWS and Kubernetes providers
   - Test resource provisioning (VPC creation, etc.)

---

## Architecture I Understand

```
┌─────────────────────────────────────────────────────────────┐
│                     AWS VPC (Terraform pre-configured)      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐                                            │
│  │ Bastion Host│ ◄── Public IP, SSH access                  │
│  │  :5000      │ ◄── OCI Registry Cache (GHCR proxy)        │
│  └─────────────┘                                            │
│         │                                                   │
│         ▼                                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Private Subnet (No public IPs)              │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │    │
│  │  │control-01│  │control-02│  │control-03│          │    │
│  │  │c7g.large │  │c7g.large │  │c7g.large │          │    │
│  │  └──────────┘  └──────────┘  └──────────┘          │    │
│  │                                                     │    │
│  │  ┌──────────┐  ┌──────────┐                        │    │
│  │  │ worker-01│  │ worker-02│  (+ more as needed)    │    │
│  │  │c7g.xlarge│  │c7g.xlarge│                        │    │
│  │  └──────────┘  └──────────┘                        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Ingress Strategy**: CloudFlare Tunnel (preferred) or Tailscale for OIDC callbacks.

---

## My Tools for This Task

| Tool | Purpose | Status |
|------|---------|--------|
| `awslabs.aws-api-mcp-server:call_aws` | Execute AWS CLI commands | ⏳ Needs session token |
| `awslabs.aws-api-mcp-server:suggest_aws_commands` | Get CLI suggestions | ✅ Available (no auth needed) |
| `Filesystem:*` | Read manifests, write scripts | ✅ Available |
| `web_fetch` / `web_search` | Research AMIs, docs | ✅ Available |

---

## Gaps in My Understanding

### Critical Questions (Need Answers Before Proceeding)

1. **VPC and Subnet IDs**
   - The manifest shows placeholders (`vpc-xxxxxxxxx`, `subnet-xxxxxxxxx`)
   - Do I discover these dynamically, or will you provide them?

2. **Region**
   - Document references `us-west-2` but default AWS MCP is `eu-west-1`
   - Which region should I target?

3. **Custom Talos Image Location**
   - Placeholder shows `ghcr.io/your-org/talos:v1.10.5-cozy-spin`
   - What's the actual image path?

4. **Bastion Host**
   - Is the bastion already running with the registry cache configured?
   - What's its private IP for registry access?

5. **`cluster-manifest.yaml` File**
   - Should I create this, or does it already exist?
   - I see the template in the docs but no actual file in the repo

6. **IAM Permissions**
   - What IAM role/profile should instances use?
   - Does `CozyStackNodeRole` instance profile exist?

### Medium Priority Questions

7. **Talos Configuration**
   - Is `talm` CLI available on my end, or does this happen on the bastion?
   - How do I get the Talos machine configs to the nodes?

8. **Key Pair**
   - EC2 instances need `--key-name` for SSH access
   - Which key pair should I use?

9. **DNS / Domain**
   - CloudFlare tunnel needs a domain
   - What domain will be used for OIDC endpoints?

10. **GitHub OAuth App**
    - Is this already configured for Dex integration?
    - Client ID/secret location?

### Lower Priority / Later Phases

11. **KubeVirt ARM64 Support**
    - This is flagged as a "sprint test" to determine feasibility
    - May require alternative multi-tenancy approach

12. **Cost Tracking**
    - Any budget constraints I should be aware of?
    - Should I use spot instances where appropriate?

---

## What I'll Do When Authorized

Once you refresh the AWS session token, I can:

### Immediate (Validation)
```bash
# Test credentials
aws sts get-caller-identity

# List VPCs and subnets to understand existing infrastructure  
aws ec2 describe-vpcs
aws ec2 describe-subnets

# Find Ubuntu ARM64 AMI
aws ec2 describe-images --owners 099720109477 --filters ...
```

### With Answers to Critical Questions
```bash
# Create security group
# Launch EC2 instances with proper networking
# Generate cloud-init for boot-to-Talos
# Tag and track resources for cleanup
```

---

## Files I Found Locally

The repo at `/Users/yebyen/u/c/cozystack-moon-and-back` contains:
- `docs/guides/AWS-ARM64-COZYSTACK-DEPLOYMENT.md` - Main deployment guide
- `docs/guides/CROSSPLANE-V2-TESTING.md` - Testing procedures
- `docs/guides/OPERATIONAL-PROCEDURES.md` - Operational reference
- Various patches and test scripts

**No `cluster-manifest.yaml` exists yet** - I'd need to create this based on discovered VPC details.

---

## Summary

I have a solid understanding of the deployment goal and process. The documentation is comprehensive. Before executing, I need:

1. **AWS session token refreshed** (you'll do MFA)
2. **Answers to critical questions** above (especially VPC/subnet details and region)
3. **Confirmation of bastion status** (registry cache ready?)

Once those are clear, I can begin the infrastructure creation phase using AWS CLI commands.
