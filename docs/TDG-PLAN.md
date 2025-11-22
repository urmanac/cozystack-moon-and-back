# Test-Driven Generation Plan: CozyStack Moon and Back

## Context for Next Claude Agent

This document follows the **Test-Driven Generation (TDG)** methodology introduced by Chanwit Kaewkasi. We define tests/acceptance criteria FIRST, then generate code that makes those tests pass.

**Reference**: [I was wrong about Test-Driven Generation](https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502)

## Project Repositories Overview

### Primary Presentation Repo (NEW)
- **urmanac/cozystack-moon-and-back**: Conference talk demo, December 3, 2025
  - Purpose: Live demo + slides for CozySummit Virtual 2025
  - Content: Terraform for AWS infrastructure, talk materials, demo scripts
  - Audience: CozyStack community

### Supporting Infrastructure Repos
- **urmanac/aws-accounts**: Terraform for all Urmanac AWS infrastructure
  - Current: Bastion ASG, VPC, security groups (Sandbox account)
  - Owner: Urmanac, LLC (Kingdon Barrett)
  
### Flux Bootstrap Repos
- **kingdon-ci/fleet-infra**: Original Flux bootstrap (may be deprecated?)
- **kingdon-ci/cozy-fleet**: NEW Flux bootstrap repo for CozyStack
  - Purpose: GitOps management of CozyStack clusters
  - Status: Determine which is active/canonical

### Questions for Operator
1. Which Flux repo is canonical: `fleet-infra` or `cozy-fleet`?
2. Should we consolidate or keep separate?
3. Are there other repos in the dependency chain?

## TDG Test Suite: Infrastructure Layer

### Test 1: Network Foundation Exists
```bash
#!/bin/bash
# tests/01-network-foundation.sh

# GIVEN: A clean AWS account in eu-west-1
# WHEN: Terraform apply completes
# THEN: The following resources exist

test_vpc_exists() {
  vpc_id=$(aws ec2 describe-vpcs \
    --filters "Name=cidr,Values=10.10.0.0/16" \
    --query 'Vpcs[0].VpcId' --output text)
  
  [ "$vpc_id" != "None" ] && [ -n "$vpc_id" ]
}

test_single_public_subnet_exists() {
  # Desktop design: Single public subnet, no private subnet needed
  public_subnet=$(aws ec2 describe-subnets \
    --filters "Name=cidr-block,Values=10.10.0.0/24" \
    --query 'Subnets[0].SubnetId' --output text)
  
  [ "$public_subnet" != "None" ] && [ -n "$public_subnet" ]
}

test_internet_gateway_only() {
  # No NAT gateway needed - IPv6 + bastion Wireguard for internet
  igw_state=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query 'InternetGateways[0].State' --output text)
  
  [ "$igw_state" = "available" ]
}

test_route_tables_configured() {
  # Private subnet should route 0.0.0.0/0 to NAT gateway
  # Public subnet should route 0.0.0.0/0 to Internet gateway
  # Both should have local routes for VPC CIDR
  
  # Implementation TBD based on Terraform structure
  true # Placeholder
}

# Run all tests
test_vpc_exists && \
test_single_public_subnet_exists && \
test_internet_gateway_only && \
test_route_tables_configured
```

**Status**: ❌ FAIL (VPC doesn't exist yet)
**Next Step**: Generate Terraform in `urmanac/aws-accounts` to make this pass

---

### Test 2: Bastion with Static ENI
```bash
#!/bin/bash
# tests/02-bastion-static-eni.sh

# GIVEN: Network foundation from Test 1
# WHEN: Bastion ASG deploys with ENI attachment
# THEN: Bastion has static IP 10.10.0.100 via ENI

test_bastion_in_private_subnet() {
  bastion_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=tf-bastion" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
  
  [ "$bastion_ip" = "10.20.13.140" ]
}

test_bastion_has_public_connectivity() {
  # Bastion should be able to reach internet via NAT gateway
  # Test by checking if it can resolve external DNS
  
  instance_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=tf-bastion" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  
  # This would require SSM or actual SSH test
  # Simplified: check security group allows egress
  true # Placeholder
}

test_bastion_reachable_from_home() {
  # SSH from operator's home IPv6 address works
  # Requires actual connection test or security group validation
  
  ssh -o ConnectTimeout=5 ubuntu@10.20.13.140 "echo 'Connected'" 2>/dev/null
}

test_bastion_scheduled_correctly() {
  # ASG should have scheduled actions for 5hrs/day
  asg_name="tf-asg"
  
  scheduled_actions=$(aws autoscaling describe-scheduled-actions \
    --auto-scaling-group-name "$asg_name" \
    --query 'length(ScheduledUpdateGroupActions)')
  
  [ "$scheduled_actions" -ge 2 ] # At least start and stop actions
}

# Run all tests
test_bastion_in_private_subnet && \
test_bastion_has_public_connectivity && \
test_bastion_reachable_from_home && \
test_bastion_scheduled_correctly
```

**Status**: ❌ FAIL (Bastion still in public subnet)
**Next Step**: Modify existing ASG/launch template in `urmanac/aws-accounts`

---

### Test 3: Netboot Infrastructure Running
```bash
#!/bin/bash
# tests/03-netboot-infrastructure.sh

# GIVEN: Bastion running in private subnet
# WHEN: User data script completes
# THEN: All Docker containers are operational

test_docker_containers_running() {
  containers=(
    "dnsmasq"
    "matchbox"
    "registry-docker.io"
    "registry-gcr.io"
    "registry-ghcr.io"
    "registry-quay.io"
    "registry-registry.k8s.io"
    "pihole"
  )
  
  for container in "${containers[@]}"; do
    ssh ubuntu@10.20.13.140 "docker ps --filter name=$container --format '{{.Names}}'" | grep -q "$container"
    if [ $? -ne 0 ]; then
      echo "FAIL: Container $container not running"
      return 1
    fi
  done
  
  echo "PASS: All containers running"
  return 0
}

test_dnsmasq_serving_dhcp() {
  # Check dnsmasq config includes DHCP range for 10.20.13.0/24
  ssh ubuntu@10.20.13.140 "docker exec dnsmasq cat /etc/dnsmasq.conf" | \
    grep -q "dhcp-range=10.20.13"
}

test_matchbox_serving_talos() {
  # Matchbox should respond on port 8080
  # Check if it has Talos boot assets
  
  curl -s http://10.20.13.140:8080/assets/talos/vmlinuz >/dev/null
}

test_registry_caches_operational() {
  # All 5 registry pull-through caches should respond
  for port in 5050 5051 5052 5053 5054; do
    curl -s http://10.20.13.140:$port/v2/ | grep -q "401 Unauthorized"
    if [ $? -ne 0 ]; then
      echo "FAIL: Registry on port $port not responding"
      return 1
    fi
  done
  
  echo "PASS: All registry caches operational"
  return 0
}

test_pihole_serving_dns() {
  # Pi-hole should resolve DNS queries
  dig @10.20.13.140 google.com +short | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
}

# Run all tests
test_docker_containers_running && \
test_dnsmasq_serving_dhcp && \
test_matchbox_serving_talos && \
test_registry_caches_operational && \
test_pihole_serving_dns
```

**Status**: ❌ FAIL (Bastion user data doesn't include container orchestration yet)
**Next Step**: Generate user data script with Docker compose or shell orchestration

---

### Test 4: Talos Node Netboots Successfully
```bash
#!/bin/bash
# tests/04-talos-netboot.sh

# GIVEN: Netboot infrastructure operational
# WHEN: Talos node instance launches
# THEN: Node boots Talos Linux from network

test_talos_node_gets_dhcp_lease() {
  # Check dnsmasq logs for DHCP lease to new node
  ssh ubuntu@10.20.13.140 "docker logs dnsmasq 2>&1 | tail -20" | \
    grep -q "DHCPACK"
}

test_talos_node_pulls_from_matchbox() {
  # Check matchbox logs for kernel/initrd requests
  ssh ubuntu@10.20.13.140 "docker logs matchbox 2>&1 | tail -20" | \
    grep -q "GET /assets/talos"
}

test_talos_node_reaches_ready_state() {
  # Use talosctl to check node health
  # Requires node IP from previous test
  
  node_ip=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=talos-node-1" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)
  
  talosctl -n "$node_ip" health --wait-timeout 5m
}

test_talos_node_uses_registry_cache() {
  # Check registry cache logs for image pulls from Talos node
  for port in 5050 5051 5052 5053 5054; do
    ssh ubuntu@10.20.13.140 "docker logs registry-*:$port 2>&1 | tail -50" | \
      grep -q "$node_ip"
  done
}

# Run all tests
test_talos_node_gets_dhcp_lease && \
test_talos_node_pulls_from_matchbox && \
test_talos_node_reaches_ready_state && \
test_talos_node_uses_registry_cache
```

**Status**: ❌ FAIL (No Talos nodes launched yet)
**Next Step**: Create Talos node launch template, test manual launch

---

### Test 5: CozyStack Cluster Operational
```bash
#!/bin/bash
# tests/05-cozystack-operational.sh

# GIVEN: 1-3 Talos nodes successfully netbooted
# WHEN: CozyStack bootstrap completes
# THEN: Kubernetes cluster is healthy with CozyStack installed

test_kubernetes_api_responding() {
  # Assumes kubeconfig available from talosctl
  talosctl -n 10.20.13.x kubeconfig
  
  kubectl cluster-info | grep -q "Kubernetes control plane is running"
}

test_cozystack_installed() {
  # Check for CozyStack CRDs and controllers
  kubectl get crds | grep -q "cozystack.io"
  kubectl get pods -n cozy-system -o wide | grep -v "0/1"
}

test_kubevirt_operational() {
  # CozyStack uses KubeVirt for VMs
  kubectl get pods -n kubevirt -o wide | grep -q "Running"
}

test_spinkube_extension_loaded() {
  # Custom Talos image includes spin runtimeclass
  kubectl get runtimeclass | grep -q "spin"
}

test_tailscale_extension_loaded() {
  # Custom Talos image includes tailscale
  # Check if tailscale daemon is running on nodes
  
  talosctl -n 10.20.13.x get services | grep -q "tailscale"
}

# Run all tests
test_kubernetes_api_responding && \
test_cozystack_installed && \
test_kubevirt_operational && \
test_spinkube_extension_loaded && \
test_tailscale_extension_loaded
```

**Status**: ❌ FAIL (CozyStack not bootstrapped yet)
**Next Step**: Follow CozyStack installation guide, document bootstrap process

---

### Test 6: Demo Workload Runs on ARM64
```bash
#!/bin/bash
# tests/06-demo-workload.sh

# GIVEN: CozyStack cluster operational
# WHEN: SpinKube demo application deploys
# THEN: Application runs successfully on ARM64 nodes

test_spinkube_demo_deploys() {
  # Deploy sample Spin application
  kubectl apply -f demo/spinkube-hello-world.yaml
  
  kubectl wait --for=condition=Ready pod -l app=spinkube-demo --timeout=2m
}

test_demo_responds_to_requests() {
  # Port-forward and curl the demo app
  kubectl port-forward svc/spinkube-demo 8080:80 &
  PF_PID=$!
  
  sleep 2
  response=$(curl -s http://localhost:8080)
  kill $PF_PID
  
  echo "$response" | grep -q "Hello from Spin"
}

test_demo_runs_on_arm64() {
  # Verify pod is scheduled on ARM64 node
  node=$(kubectl get pod -l app=spinkube-demo \
    -o jsonpath='{.items[0].spec.nodeName}')
  
  arch=$(kubectl get node "$node" \
    -o jsonpath='{.status.nodeInfo.architecture}')
  
  [ "$arch" = "arm64" ]
}

test_demo_uses_cozystack_features() {
  # Demonstrate CozyStack tenant isolation or other features
  # TBD based on specific demo requirements
  
  true # Placeholder
}

# Run all tests
test_spinkube_demo_deploys && \
test_demo_responds_to_requests && \
test_demo_runs_on_arm64 && \
test_demo_uses_cozystack_features
```

**Status**: ❌ FAIL (No demo workload created yet)
**Next Step**: Create SpinKube hello-world manifest, test deployment

---

## TDG Test Suite: Flux GitOps Layer

### Test 7: Flux Bootstrap Successful
```bash
#!/bin/bash
# tests/07-flux-bootstrap.sh

# GIVEN: CozyStack cluster operational
# WHEN: Flux bootstrap completes from cozy-fleet repo
# THEN: Flux controllers are running and syncing

test_flux_namespace_exists() {
  kubectl get namespace flux-system
}

test_flux_controllers_running() {
  controllers=(
    "source-controller"
    "kustomize-controller"
    "helm-controller"
    "notification-controller"
  )
  
  for controller in "${controllers[@]}"; do
    kubectl get deployment -n flux-system "$controller" \
      -o jsonpath='{.status.availableReplicas}' | grep -q "^1$"
  done
}

test_flux_syncing_from_cozy_fleet() {
  # Check GitRepository points to correct repo
  repo=$(kubectl get gitrepository -n flux-system flux-system \
    -o jsonpath='{.spec.url}')
  
  echo "$repo" | grep -q "kingdon-ci/cozy-fleet"
}

test_kustomizations_healthy() {
  # All Kustomizations should be Ready
  kubectl get kustomizations -A -o json | \
    jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True")) | .metadata.name' | \
    [ -z "$(cat)" ]
}

# Run all tests
test_flux_namespace_exists && \
test_flux_controllers_running && \
test_flux_syncing_from_cozy_fleet && \
test_kustomizations_healthy
```

**Status**: ❌ FAIL (Flux not bootstrapped yet)
**Next Step**: Determine canonical Flux repo, run bootstrap command

---

## TDG Test Suite: Cost & Compliance Layer

### Test 8: Staying Within Free Tier
```bash
#!/bin/bash
# tests/08-cost-compliance.sh

# GIVEN: Infrastructure running for experiment duration
# WHEN: Checking AWS Cost Explorer
# THEN: Costs remain under target threshold

test_monthly_cost_under_target() {
  # Target: < $0.10/month
  
  current_month=$(date +%Y-%m-01)
  next_month=$(date -d "$current_month + 1 month" +%Y-%m-01)
  
  cost=$(aws ce get-cost-and-usage \
    --time-period Start="$current_month",End="$next_month" \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
    --output text)
  
  # Convert to cents for integer comparison
  cost_cents=$(echo "$cost * 100" | bc | cut -d. -f1)
  
  [ "$cost_cents" -lt 10 ]
}

test_t4g_free_tier_not_exceeded() {
  # Check t4g instance hours don't exceed 750/month
  
  # This requires custom metric or CloudWatch query
  # Simplified: count running t4g instances
  
  running_t4g=$(aws ec2 describe-instances \
    --filters "Name=instance-type,Values=t4g.*" \
              "Name=instance-state-name,Values=running" \
    --query 'length(Reservations[*].Instances[*])')
  
  # With 4 instances at 5hrs/day = 600hrs/month, under 750
  [ "$running_t4g" -le 4 ]
}

test_no_unexpected_charges() {
  # Check for charges from unexpected services
  
  services=$(aws ce get-cost-and-usage \
    --time-period Start="$current_month",End="$next_month" \
    --granularity MONTHLY \
    --metrics BlendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[].Keys[0]' \
    --output text)
  
  # Should only see: EC2, EBS, (maybe S3 for Terraform state)
  echo "$services" | grep -qv -E "(RDS|Lambda|ECS|EKS|ElastiCache)"
}

# Run all tests
test_monthly_cost_under_target && \
test_t4g_free_tier_not_exceeded && \
test_no_unexpected_charges
```

**Status**: ⚠️  PARTIAL (Current costs ~$0.04/month, but no Talos nodes running yet)
**Next Step**: Monitor costs during experiments, implement auto-termination

---

### Test 9: GDPR Compliance (Zero Risk Mode)
```bash
#!/bin/bash
# tests/09-gdpr-compliance.sh

# GIVEN: Infrastructure fully deployed
# WHEN: Auditing network configuration
# THEN: No public services accessible, zero GDPR risk

test_no_public_facing_services() {
  # Check security groups - no ingress from 0.0.0.0/0 except SSH to bastion
  
  public_ingress=$(aws ec2 describe-security-groups \
    --filters "Name=ip-permission.cidr,Values=0.0.0.0/0" \
    --query 'SecurityGroups[].GroupId' \
    --output text)
  
  # Should only find bastion security group (if any)
  # Talos nodes should have no public ingress
  
  for sg in $public_ingress; do
    name=$(aws ec2 describe-security-groups \
      --group-ids "$sg" \
      --query 'SecurityGroups[0].GroupName' \
      --output text)
    
    # Only bastion-sg allowed to have public SSH (from specific IPv6)
    if [ "$name" != "bastion-sg" ]; then
      echo "FAIL: Unexpected public security group: $name"
      return 1
    fi
  done
}

test_no_public_ip_addresses() {
  # Talos nodes should have NO public IPs
  
  public_ips=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=talos-node-*" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text)
  
  [ -z "$public_ips" ]
}

test_all_traffic_private() {
  # VPC flow logs would show no traffic to/from internet
  # Except through NAT gateway for egress
  
  # Simplified: check route tables
  # Talos nodes subnet should only route to NAT, not IGW
  
  true # Placeholder - requires actual flow log analysis
}

# Run all tests
test_no_public_facing_services && \
test_no_public_ip_addresses && \
test_all_traffic_private
```

**Status**: ⚠️  PARTIAL (Need to verify after deployment)
**Next Step**: Audit security groups and routing tables

---

## Repository Integration Strategy

### Code Generation Targets

**Primary**: `urmanac/cozystack-moon-and-back` (presentation repo)
- `/terraform/` - Infrastructure code (may reference aws-accounts modules)
- `/tests/` - TDG test suite (these bash scripts)
- `/demo/` - SpinKube demo manifests
- `/slides/` - Talk materials (Markdown → reveal.js?)
- `/docs/` - Setup guides, troubleshooting

**Secondary**: `urmanac/aws-accounts` (infrastructure repo)
- Modify existing Terraform for new VPC/subnets
- Add bastion user data for Docker containers
- Create Talos node launch template

**Tertiary**: `kingdon-ci/cozy-fleet` (Flux bootstrap)
- Determine if this is canonical or should migrate to presentation repo
- Add CozyStack-specific Flux resources
- Configure tenants, policies, etc.

### Decision Tree for Code Placement

```
Is it infrastructure (VPC, EC2, IAM)?
├─ YES → urmanac/aws-accounts (Terraform)
└─ NO
   Is it Kubernetes/Flux configuration?
   ├─ YES → kingdon-ci/cozy-fleet (GitOps)
   └─ NO
      Is it demo-specific or talk materials?
      ├─ YES → urmanac/cozystack-moon-and-back
      └─ NO → Determine new home or extend existing repo
```

### Flux Repository Consolidation Question

**Need operator input:**
1. Keep separate `cozy-fleet` repo for production GitOps?
2. Create new Flux bootstrap in `cozystack-moon-and-back` for demo?
3. Migrate everything to one canonical location?

**Recommendation**: Demo in `cozystack-moon-and-back`, production in `cozy-fleet`

---

## Next Actions for Claude Agent (Priority Order)

### Week 1: Foundation (Nov 17-23)
1. **Generate VPC Terraform** → Make Test 1 pass
   - Target: `urmanac/aws-accounts` or `cozystack-moon-and-back/terraform/`
   - Deliverable: VPC, subnets, NAT gateway, route tables
   
2. **Modify Bastion for Private Subnet** → Make Test 2 pass
   - Target: `urmanac/aws-accounts` (existing ASG/launch template)
   - Deliverable: Bastion at 10.20.13.140, SSH from home IPv6

3. **Generate Bastion User Data** → Make Test 3 pass
   - Target: `cozystack-moon-and-back/terraform/user-data.sh`
   - Deliverable: Docker containers running (dnsmasq, matchbox, registries, pihole)

### Week 2: Talos & CozyStack (Nov 24-30)
4. **Create Talos Launch Template** → Make Test 4 pass
   - Target: `urmanac/aws-accounts` or `cozystack-moon-and-back/terraform/`
   - Deliverable: Manual launch works, netboot successful

5. **Bootstrap CozyStack** → Make Test 5 pass
   - Target: Document in `cozystack-moon-and-back/docs/bootstrap.md`
   - Deliverable: Kubernetes cluster with CozyStack installed

6. **Setup Flux GitOps** → Make Test 7 pass
   - Target: Determine canonical repo, bootstrap Flux
   - Deliverable: Flux syncing from Git, ready for app deployments

### Week 3: Demo & Polish (Dec 1-4)
7. **Create SpinKube Demo** → Make Test 6 pass
   - Target: `cozystack-moon-and-back/demo/spinkube-hello.yaml`
   - Deliverable: Working demo app on ARM64

8. **Build Talk Materials**
   - Target: `cozystack-moon-and-back/slides/`
   - Deliverable: Slide deck with live demo script

9. **Practice & Contingency Plans**
   - Fallback: Home lab demo if AWS has issues
   - Prepare backup slides with cost data and architecture diagrams

---

## Success Criteria (TDG-Style)

**Minimum Viable Demo (December 3):**
- [ ] Test 1-3 passing (Network + Bastion)
- [ ] Test 4 passing (At least 1 Talos node netboots)
- [ ] Test 5 partial (CozyStack installed, even if not production-ready)
- [ ] Test 6 passing (SpinKube hello-world runs)
- [ ] Test 8 passing (Cost < $0.10/month proven)
- [ ] Slides + demo script ready

**Stretch Goals:**
- [ ] Test 7 passing (Flux GitOps working)
- [ ] Test 9 passing (GDPR compliance audit documented)
- [ ] 3-node cluster (vs. 1-node minimum)
- [ ] Custom Talos image with Tailscale + Spin extensions built

**Ultimate Goal:**
- Audience leaves thinking: "I could replicate this in my own environment"
- Community feedback: "This is a realistic approach to hybrid cloud"
- Operator satisfaction: "I learned something building this, and so did they"

---

## TDG Success Story: Custom Talos Images (Nov 16-17, 2025)

### The Problem: ARM64 Talos Images with Spin + Tailscale

**Initial Requirement**: Build custom ARM64 Talos images with Spin runtime and Tailscale extensions for CozyStack deployment on AWS t4g instances.

**Classic Anti-Pattern (What We Almost Did)**:
1. Start writing GitHub Actions workflow from scratch
2. Guess at patch format by looking at examples  
3. Trial-and-error approach with commit-push-check cycles
4. Debug failures by reading CI logs and making assumptions
5. Accumulate "almost working" patches and debugging artifacts
6. End up with 20+ commits of incremental fixes and confusion

### The TDG Approach (What Actually Worked)

#### Red Phase: Write Tests First
Before writing any GitHub Actions or patch files, we defined **exactly** what success looks like:

```bash
# Test: Patch should apply cleanly to upstream
cd /tmp && git clone https://github.com/cozystack/cozystack.git
cd cozystack && git apply --check /path/to/our.patch

# Test: Expected changes should be present  
grep "EXTENSIONS.*spin tailscale" packages/core/installer/hack/gen-profiles.sh
grep "arch: arm64" packages/core/installer/hack/gen-profiles.sh
grep "SPIN_IMAGE\|TAILSCALE_IMAGE" packages/core/installer/hack/gen-profiles.sh
```

**Key Insight**: Tests defined the exact file changes needed BEFORE we tried to create patches.

#### Green Phase: Make Tests Pass (The Hard Part)
**First Attempt**: Manual patch construction → Failed spectacularly
- Hand-crafted unified diff format
- Wrong line numbers (humans are bad at counting)
- Malformed patch structure ("fragment without header")
- Multiple debugging cycles with broken patches

**Second Attempt**: Git-generated patches → Succeeded immediately
```bash
# Make actual changes to files
cd /tmp/cozystack
sed -i 's/EXTENSIONS="drbd zfs"/EXTENSIONS="drbd zfs spin tailscale"/' hack/gen-profiles.sh
sed -i 's/arch: amd64/arch: arm64/' hack/gen-profiles.sh
# ... other changes

# Let Git create proper patch
git diff > working.patch
git apply --check working.patch  # ✓ PASSES
```

**Critical Lesson**: Don't outsmart the tools. Use `git diff` to create patches, not string manipulation.

#### Refactor Phase: Clean and Validate
**Problem Discovered**: Multiple patch files in directory caused sequential application failures
- `01-arm64-spin-tailscale.patch` (working) 
- `01-gen-profiles-only.patch` (leftover debugging, broken)
- `test-*.patch` (various debugging artifacts)

**Solution**: Cleanup + Comprehensive validation
```bash
# Remove all debugging artifacts
rm patches/test-*.patch patches/*-only.patch

# Create validation suite to prevent future regressions
./validate-complete.sh
# ✓ Patch applies cleanly to upstream
# ✓ All expected changes present
# ✓ Workflow syntax valid  
# ✓ Dependencies configured
# ✓ Clean patch directory
```

### Results: From Chaos to Confidence

**Before TDG (Typical Approach)**:
- 15+ commits over multiple hours
- "patch fragment without header" errors
- "corrupt patch at line X" failures
- Manual debugging of GitHub Actions output
- Guessing what might be wrong
- Stream of half-working incremental fixes

**After TDG (Test-First Approach)**:
- 3 clean commits: working patch + validation suite + docs
- Immediate success on each GitHub Actions run
- Local validation prevents CI failures
- Clear understanding of what each component does
- Reusable patterns for future patch generation

### Key TDG Principles Validated

1. **Tests First**: Writing validation scripts forced us to understand what "success" actually meant
2. **Red-Green-Refactor**: Each cycle improved both the solution and our understanding
3. **Local Feedback**: Running tests locally is infinitely faster than CI debugging
4. **Documentation**: Writing ADR-003 prevented future developers (including ourselves) from repeating mistakes

### Broader Applicability

This same TDG approach applies to:
- **Terraform**: Write `terraform plan` assertions before writing resources
- **Kubernetes**: Write `kubectl wait` tests before creating manifests
- **Docker**: Write container health checks before Dockerfile optimization
- **Any Infrastructure Code**: Define observable success criteria first

### The Validation Suite Legacy

The `validate-complete.sh` script now ensures:
- No future patch generation mistakes
- Workflow changes are validated locally
- Repository cleanliness is maintained
- Documentation stays in sync

**Future developers can run one command and know their changes will work.**

### Quote from the Trenches
> "When you force yourself to write a test, you can run the test, and you don't get a stream of commits of half-garbage because nobody knows how to write this stuff from scratch!"

**The TDG methodology transformed debugging chaos into engineering confidence.**

---

---

## Handoff Notes for Next Claude Agent

**Operator context:**
- Works at NASA (via Navteca, LLC) but presenting personal work
- Home lab generates significant heat and power consumption
- Already has working home lab with Talos + CozyStack
- Needs cloud replica for talk demo + to prove economics
- Conference: CozySummit Virtual 2025, December 3 (~12 days)
- Budget: Stay within AWS free tier (<$0.10/month)

**Technical state:**
- AWS account: Sandbox (181107798310)
- Region: eu-west-1
- Existing: Bastion in public subnet, scheduled 5hrs/day
- MFA'd AWS credentials working via profile `sb-terraform-mfa-session`
- Terraform: Split between `urmanac/aws-accounts` and new presentation repo
- Flux: Unclear which repo is canonical (`fleet-infra` vs `cozy-fleet`)

**Immediate priorities:**
1. Generate Terraform for VPC/subnets (Test 1)
2. Move bastion to private subnet (Test 2)
3. Add Docker containers to bastion user data (Test 3)

## TDG Test Suite: Integration Layer

### Test 10: SpinApp GitOps Deployment
```bash
#!/bin/bash
# tests/10-spinapp-gitops.sh

# GIVEN: CozyStack cluster operational from Test 5
# WHEN: GitOps repository contains SpinApp manifest
# THEN: Application serves externally via MetalLB

test_spinapp_deployed() {
  # Check SpinApp CRD exists and application is ready
  kubectl get spinapp demo-spin-app -n demo \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"
}

test_metallb_service_allocated() {
  # Verify MetalLB allocated external IP from ARP pool
  external_ip=$(kubectl get svc demo-spin-app -n demo \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  
  [[ "$external_ip" =~ ^10\.20\.1\.[0-9]+$ ]] # VPC subnet range
}

test_external_access_works() {
  # Test HTTP access from within VPC (bastion perspective)
  ssh bastion "curl -f http://$external_ip:8080/health" | grep -q "OK"
}

test_gitops_sync_working() {
  # Verify Flux/ArgoCD shows application in sync
  # Implementation depends on GitOps tool choice
  kubectl get gitrepository cozy-apps -n flux-system \
    -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"
}

# Run all tests
test_spinapp_deployed && \
test_metallb_service_allocated && \
test_external_access_works && \
test_gitops_sync_working
```

**Status**: ❌ FAIL (No cluster yet)
**Dependencies**: Tests 1-5 (infrastructure), GitOps repository
**Demo Value**: ⭐⭐⭐⭐⭐ (Shows WebAssembly + GitOps + LoadBalancer)

---

### Test 11: KubeVirt Cluster-API Integration  
```bash
#!/bin/bash
# tests/11-kubevirt-cluster-api.sh

# GIVEN: CozyStack with KubeVirt provider from Test 5
# WHEN: Cluster-API creates guest Kubernetes cluster
# THEN: Nested cluster runs workloads successfully

test_cluster_api_ready() {
  # Verify Cluster-API controllers operational
  kubectl get clusters -A | grep -q "Provisioned.*True"
}

test_guest_cluster_accessible() {
  # Extract guest cluster kubeconfig and test access
  kubectl get secret guest-cluster-kubeconfig -o jsonpath='{.data.value}' \
    | base64 -d > /tmp/guest-kubeconfig
  
  KUBECONFIG=/tmp/guest-kubeconfig kubectl get nodes | grep -q "Ready"
}

test_nested_workload_scheduling() {
  # Deploy simple workload to guest cluster
  KUBECONFIG=/tmp/guest-kubeconfig kubectl run test-pod \
    --image=nginx:alpine --restart=Never
  
  KUBECONFIG=/tmp/guest-kubeconfig kubectl wait pod test-pod \
    --for=condition=Ready --timeout=300s
}

test_vm_resource_isolation() {
  # Verify VMs have proper resource limits
  kubectl get virtualmachine -A -o jsonpath='{.items[*].spec.template.spec.domain.resources}'
}

# Run all tests  
test_cluster_api_ready && \
test_guest_cluster_accessible && \
test_nested_workload_scheduling && \
test_vm_resource_isolation
```

**Status**: ❌ FAIL (No KubeVirt yet) 
**Dependencies**: Test 5 (CozyStack), KubeVirt + Cluster-API setup
**Demo Value**: ⭐⭐⭐⭐ (Shows infrastructure-as-code for Kubernetes)

---

### Test 12: Moonlander + Harvey Cross-Cluster Management
```bash  
#!/bin/bash
# tests/12-moonlander-harvey-integration.sh

# GIVEN: Multiple clusters from Tests 5 + 11
# WHEN: Moonlander copies kubeconfigs for Harvey
# THEN: Harvey (Crossplane) manages all clusters uniformly

test_moonlander_secret_propagation() {
  # Verify Moonlander copied guest cluster kubeconfig to Harvey namespace
  kubectl get secret guest-cluster-kubeconfig -n harvey-system \
    -o jsonpath='{.data.kubeconfig}' | base64 -d | grep -q "clusters:"
}

test_harvey_crossplane_connectivity() {
  # Check Harvey can list resources across all clusters
  kubectl get providerconfigs -n harvey-system | grep -q "guest-cluster"
  
  # Verify Crossplane can reach guest cluster
  kubectl logs -n harvey-system deployment/harvey-controller | grep -q "successfully connected to guest-cluster"
}

test_cross_cluster_workload_deployment() {
  # Harvey deploys workload to guest cluster via Crossplane
  cat <<EOF | kubectl apply -f -
apiVersion: harvey.io/v1alpha1  
kind: CrossClusterWorkload
metadata:
  name: test-cross-deployment
  namespace: harvey-system
spec:
  targetCluster: guest-cluster
  template:
    apiVersion: v1
    kind: Pod
    metadata:
      name: harvey-managed-pod
    spec:
      containers:
      - name: test
        image: alpine:latest
        command: [sleep, "3600"]
EOF

  # Wait for Harvey to propagate workload
  sleep 30
  
  KUBECONFIG=/tmp/guest-kubeconfig kubectl get pod harvey-managed-pod | grep -q "Running"
}

test_unified_cluster_visibility() {
  # Verify Harvey dashboard shows both host and guest clusters
  kubectl port-forward -n harvey-system svc/harvey-dashboard 8080:80 &
  sleep 5
  curl -f http://localhost:8080/api/clusters | jq '.clusters | length' | grep -q "2"
  pkill -f "kubectl port-forward"
}

# Run all tests
test_moonlander_secret_propagation && \
test_harvey_crossplane_connectivity && \
test_cross_cluster_workload_deployment && \
test_unified_cluster_visibility  
```

**Status**: ❌ FAIL (No Moonlander/Harvey yet)
**Dependencies**: Tests 5 + 11, Moonlander secret propagation, Harvey/Crossplane
**Demo Value**: ⭐⭐⭐⭐⭐ (Shows advanced multi-cluster orchestration)

---

**When operator returns, start with:**
"Welcome back! I've expanded the TDG test suite to include integration tests 10-12. These cover SpinApp GitOps deployment, KubeVirt nested clusters, and Moonlander+Harvey cross-cluster management. We now have 12 tests defined total. Want me to generate the VPC Terraform to make Test 1 pass first?"

---

*Document created: 2025-11-16*  
*TDG methodology: Write tests first, generate code to make them pass*  
*Target: CozySummit Virtual 2025, December 3, 2025*  
*For talk: "Home Lab to the Moon and Back" by Kingdon Barrett*

---

## Related Documentation

- 📝 **[Session Learnings](SESSION-LEARNINGS.md)** - Deep architectural discoveries and TDG methodology application from November 16, 2025
