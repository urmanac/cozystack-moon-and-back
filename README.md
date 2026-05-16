# 🚀 Home Lab to the Moon and Back

> **Validating ARM64 Kubernetes in the cloud before committing to bare-metal**  
> *Smart validation strategy: Test first, buy hardware second*

[![CozySummit Virtual 2026](https://img.shields.io/badge/CozySummit-May%2026%2C%202026-blue)](https://community2.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2026/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Built with TDG](https://img.shields.io/badge/built%20with-TDG-purple)](https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502)

---

## 🎯 The Mission

Transform a **128°F office space heater** (aka home lab) into a **cloud-validated, ARM64-first Kubernetes deployment** that:

- ✅ Validates ARM64 architecture on t4g instances before Raspberry Pi purchase
- ✅ Runs experiments within reasonable budget (baseline: $0.08/month, validation: <$15/month)
- ✅ Netboots Talos Linux with custom extensions (Spin + Tailscale subnet router)
- ✅ Demonstrates WebAssembly on ARM64 in production-like conditions
- ✅ Proves when cloud makes sense vs. efficient home lab hardware

**Target**: Live demo at [CozySummit Virtual 2026](https://community2.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2026/) on **May 26, 2026**

### 🧪 TDG Test Status (Updated: November 19, 2025)

**✅ Working Tests (4/5)**:
- ✅ Patch validation (upstream conformance) - **FIXED**
- ✅ GitHub Actions workflow syntax
- ✅ Dependency verification (crane, skopeo, jq)
- ✅ Patch directory cleanliness (3 patches) - **FIXED**

**❌ Failing Tests (1/5)**:
- ❌ ADR-003 documentation validation - Missing file expected by test

**🚧 Image Build Tests (1/3 passing)**:
- ❌ Container image pulls (need actual published images)
- ❌ OCI manifest validation (images not yet published)
- ✅ Cost tracking validation

**🎯 Conformance Achieved**:
- Upstream CozyStack integration ✅
- Separate repository strategy ✅  
- ARM64 native builds ✅
- Test suite reality alignment ✅ **NEW**

---

## 🌡️ The Problem

```
Home Lab Status: 🔥
Office Temperature: 93°F (ambient, with the door closed)
Electricity Bill: 📈
Wife's Patience: 📉
```

Running x86 workloads 24/7 in a home lab is:
- **HOT** - Space heater in every season
- **EXPENSIVE** - Power consumption adds up
- **LOUD** - Fans, lots of fans
- **INFLEXIBLE** - Can't easily scale down

**The Solution?** Validate in the cloud, then bring it home on ARM64 (Raspberry Pi CM3).

---

## 🏗️ The Architecture

### Home Lab (Current)
```
Internet → DD-WRT Router (10.17.12.1)
           └─ Front Subnet (10.17.12.0/24)
              └─ Mikrotik Router (dual-homed)
                 └─ Inner Subnet (10.17.13.0/24)
                    ├─ Netboot Infrastructure
                    │  ├─ dnsmasq (DHCP)
                    │  ├─ matchbox (PXE)
                    │  ├─ 5x registry caches
                    │  └─ pi-hole (DNS)
                    └─ Talos Nodes
                       └─ CozyStack
```

### AWS Cloud (✅ Design Complete)
```
VPC: 10.10.0.0/16 (eu-west-1) 
└─ Public Subnet (10.10.0.0/24)
   ├─ Bastion: 10.10.0.100 (ENI + IPv6, t4g.small)
   │  └─ Services: registry caches, Wireguard NAT, Tailscale
   │
   ├─ Talos Gateway: 10.10.0.101 (t4g.medium)
   │  └─ Extensions: spin, tailscale (subnet router)
   │  
   ├─ Talos Compute: 10.10.0.102 (t4g.medium)
   │  └─ Extensions: spin only
   │
   └─ Talos Compute: 10.10.0.103 (t4g.medium)
      └─ Extensions: spin only
      
Boot: boot-to-talos installs OCI images (no AMI management)
Cost: ~$16-20/month (mostly EBS, t4g free tier covers compute)
```

**📋 [AWS Design Summary](docs/AWS-DESIGN-SUMMARY.md)** - Ready for Stakpak agent  
**🏷️ [Package Naming Cleanup](docs/PACKAGE-NAMING-CLEANUP.md)** - Fix those ugly package names!

**Key Innovation**: Exact replica of home lab topology in AWS, staying within free tier limits.

---

## 🌟 Core Stack Deep Dive

**Talos Linux** · **CozyStack** · **WebAssembly (Spin)** · **Tailscale Subnet Router** · **AWS Graviton**

### 🔌 Tailscale Subnet Router Architecture

**Key insight**: We use Tailscale's **subnet router mode** (not mesh!) to create clean network bridges between:
- AWS VPC private networks (`10.20.0.0/16`)
- Kubernetes pod CIDR (managed by CozyStack's CNI)
- Service networks (MetalLB load balancers in ARP mode) 
- Home lab networks (`10.17.13.0/24`)

**Architecture**: Single privileged Talos node runs subnet router, other nodes use standard Kubernetes networking. This preserves CNI while providing seamless VPC access.

*See [landing page](https://urmanac.github.io/cozystack-moon-and-back/#tailscale-subnet-router-architecture) for complete technical implementation details.*

### 🗿 Talos Linux: Security-First Immutability

**Why Talos?** It's **CozySummit** and CozyStack is built on it. End of justification! 🎯

**What makes it compelling**:
- **Immutable OS**: Fewer binaries = smaller attack surface
- **Kubernetes-first**: No SSH, no shell, just API-driven infrastructure
- **ARM64 native**: First-class support, not an afterthought
- **Security by design**: Minimal surface area, everything locked down

**Real talk**: We're not here to justify Talos vs. other distros. It's proven, it works, and it's what CozyStack uses. Moving on.

### 🏗️ CozyStack: Helm-First Platform Engineering

**Why CozyStack over vanilla Kubernetes?** Because it looks like something I'd build if I had unlimited time, and **I want that to exist**.

**The compelling architecture**:
- **Helm-first design**: Platform built for teams that demand "Helm only" 
- **Flux integration**: GitOps workflows that actually work
- **Cloud-native foundation**: CNCF projects with (hopefully) spectacular ARM64 support
- **Platform-as-code**: Infrastructure that scales with your team, not against it

**Author's note**: As a Flux maintainer, I've seen enough infrastructure built on Helm to know this is the right abstraction level. CozyStack delivers that vision.

### ⚡ WebAssembly (Spin): Architecture-Independent Performance

**Why WebAssembly?** **Faster, cheaper, architecture-independent.** Perfect for ARM64 validation.

**The Spin advantage**:
- **Cold start performance**: Sub-millisecond startup vs. container seconds
- **Scale-to-zero efficiency**: Actually works, unlike most "serverless" promises  
- **Local registry caching**: Artifact caching that makes cold starts even faster
- **Architecture portability**: Same binary runs on x86 home lab and ARM64 cloud

**Real-world impact**: We've been demoing Spin for years. The performance story is proven - now we're validating it on ARM64 at cloud scale before hardware investment.

### 🏔️ AWS Graviton: Free Tier ARM64 Validation

**Why Graviton?** It's **available ARM64 in the cloud** and currently **free** under AWS free tier usage.

**The pragmatic choice**:
- **Virtualization extensions**: Hopefully has what Raspberry Pi lacks for advanced CozyStack features
- **Known platform**: AWS is familiar territory for cloud validation
- **Risk mitigation**: Test architecture before $650+ hardware investment
- **Uncertain alternatives**: Ampere? Chinese Raspberry Pi clones? Unknown landscape.

**Honest assessment**: We think Graviton has the virtualization support that consumer ARM64 hardware might lack. We'll find out! But we'd rather discover limitations in the cloud than after buying hardware.

### 🏗️ Role-Based Architecture: Real-World Discovery

**The Problem**: Adding Tailscale to ALL cluster nodes breaks everything.

**What we learned** (the hard way):
- **Kubernetes Ready condition**: Nodes wait for ALL configured extensions to become active
- **Multiple subnet routers**: Every node tries to configure as Tailscale subnet router  
- **Configuration conflicts**: Multiple nodes compete for same routing role
- **Cluster formation failure**: Nodes hang indefinitely, never reach Ready state

**The Solution**: Role-based image architecture
- **Compute nodes** (`spin-only`): WebAssembly runtime only, quick Ready state
- **Gateway nodes** (`spin-tailscale`): WebAssembly + Tailscale subnet router, one per cluster

**Discovery method**: "Walking the grounds and tilling the soil" - not systematic testing, but real-world cluster building experience on AMD64 that informed our ARM64 strategy.

**Impact**: This architectural insight is **why** our ARM64 validation will work. We've already solved the hard problems.

---

## 📊 The Economics

### Cost Strategy

**Baseline Infrastructure (no experiments):**
```
Bastion (t4g.small, 5hrs/day):  $0.00 (free tier)
EBS volumes (during runtime):   $0.04/month  
NAT Gateway (minimal usage):    $0.04/month
-------------------------------------------------
Baseline cost:                  $0.08/month
```

**Validation Phase (5 experiments, 2-3 hours each):**
```
3x Talos nodes (t4g.small):     $0.00 (free tier < 750hrs/month)
4x EBS volumes (8GB each):      $0.25-0.50/session
NAT Gateway (active egress):    $0.15-0.35/session  
-------------------------------------------------
Per experiment session:         $0.40-0.85
Target validation budget:       <$15/month
```

**Break-even Analysis:**
- Home lab power consumption: $30-50/month
- Cloud validation phase: Target <$15/month
- Production cloud cost: $25-70/month (estimated)
- **Decision point**: When cloud exceeds $40/month, efficient ARM64 home lab wins

**Strategy**: Validate in cloud for less than the cost of buying wrong hardware ($500+ Raspberry Pi mistake), then deploy with confidence.

---

## 🧪 Test-Driven Generation (TDG)

This project follows the **Test-Driven Generation** methodology created by [Chanwit Kaewkasi](https://github.com/chanwit).

**Principle**: Write tests FIRST, then generate code to make them pass.

### Read More:
- 📝 [Chanwit's Article: "I Was Wrong About Test-Driven Generation"](https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502)
- 🧰 [TDG Skill (Open Source)](https://github.com/chanwit/tdg)
- 📋 [Our TDG Plan](docs/TDG-PLAN.md)

### Test Status: Two-Track Approach

#### ✅ Patch & Image Validation (Current Suite)
| Test Category | Status | Details |
|--------------|--------|---------|
| Patch Validation | ✅ **PASSING** | 4/5 tests passing (validate-complete.sh) |
| Image Build Tests | 🚧 **PARTIAL** | 1/3 passing (need published images) |
| Cost Tracking | ✅ **PASSING** | AWS cost validation working |

#### 🚧 Infrastructure TDG Suite (Planned)
| Phase | Tests | Status |
|-------|-------|--------|
| Network Foundation | 1-3 | 📋 **DEFINED** (TDG-PLAN.md) |
| Bastion & Netboot | 4-6 | 📋 **DEFINED** (TDG-PLAN.md) |
| CozyStack Deployment | 7-9 | 📋 **DEFINED** (TDG-PLAN.md) |
| Integration Tests | 10-12 | 📋 **DEFINED** (SpinApp + KubeVirt + Moonlander) |

**Run current tests**: `./validate-complete.sh` and `./tests/run-all-custom-image-tests.sh`  
**Next**: Implement TDG infrastructure tests from [TDG-PLAN.md](docs/TDG-PLAN.md)

**Integration Test Highlights**:
- ✨ **Test 10**: SpinApp GitOps deployment with MetalLB external access
- 🔄 **Test 11**: KubeVirt + Cluster-API nested Kubernetes clusters  
- 🌐 **Test 12**: Moonlander + Harvey cross-cluster management via Crossplane

---

## 📚 Documentation

### Core Documents
- 🎨 [Genesis Design Doc](https://claude.ai/public/artifacts/50a73a57-0ebb-4732-95fc-43ccc1ef017c) - Original vision
- 🧪 [TDG Plan](https://claude.ai/public/artifacts/e71fc7aa-f756-4c0a-b413-a80672791f7c) - Test-driven development roadmap
- 🗺️ [Repository Overview](https://claude.ai/public/artifacts/1e7205a0-672a-46c8-8d37-0a2aeec5f657) - Full constellation map
- 📖 [README](https://claude.ai/public/artifacts/208614e9-7f5c-4824-af43-2a5591ce68c2) - This README.md, gen. Claude Desktop
- 💰 [COST](docs/COST.md)

### Repository Constellation

This project integrates with 8+ repositories:

| Repo | Purpose | Status |
|------|---------|--------|
| [urmanac/aws-accounts](https://github.com/urmanac/aws-accounts) | Infrastructure Terraform | ✅ Active |
| [kingdon-ci/cozy-fleet](https://github.com/kingdon-ci/cozy-fleet) | Flux GitOps | ✅ Active |
| [cozystack/talm](https://github.com/cozystack/talm) | GitOps Talos Management | 🎯 Core Tool |
| [kingdon-ci/kaniko-builder](https://github.com/kingdon-ci/kaniko-builder) | Custom image builds | 🔧 Tool |
| [kingdon-ci/time-tracker](https://github.com/kingdon-ci/time-tracker) | Session tracking | ⚙️ Optional |
| [kingdonb/mecris](https://github.com/kingdonb/mecris) | MCP server patterns | 🐕 Reference |
| [kingdon-ci/noclaude](https://github.com/kingdon-ci/noclaude) | Self-hosted AI | 🤖 Future |
| [chanwit/tdg](https://github.com/chanwit/tdg) | TDG Methodology | 📖 Methodology |

**See**: [docs/REPO-OVERVIEW.md](docs/REPO-OVERVIEW.md) for full dependency graph.

---

## 🎬 The Demo

### What You'll See (December 3)

1. **Home Lab Reality Check** 🔥
   - Temperature monitoring
   - Power consumption
   - The space heater problem

2. **AWS Economics** 💰
   - Live cost explorer query
   - $0.04/month current state
   - Free tier breakdown

3. **Netboot Magic** ⚡
   - Launch t4g.small instance
   - Watch Talos netboot (< 5 min)
   - CozyStack dashboard

4. **SpinKube on ARM64** 🎯
   - Deploy demo app
   - Show running workload
   - Verify ARM64 architecture

5. **The Exit** 🚪
   - Terminate instance
   - Return to $0.04/month
   - Compare to home lab costs

### Live Channels
- 📺 YouTube: [@yebyen/streams](https://youtube.com/@yebyen/streams)
- 🎥 CozyStack Speed Runs: Previous demos and validation runs

---

## 🚀 Quick Start

### Prerequisites
```bash
# AWS CLI with MFA-authenticated profile
aws configure --profile sb-terraform-mfa-session

# Terraform (or OpenTofu)
brew install opentofu

# kubectl + talosctl
brew install kubectl
brew install siderolabs/tap/talosctl

# Flux CLI
brew install fluxcd/tap/flux
```

### Deploy Infrastructure

```bash
# Clone this repo
git clone https://github.com/urmanac/cozystack-moon-and-back.git
cd cozystack-moon-and-back

# Review TDG tests
./tests/run-all.sh --dry-run

# Deploy network foundation (Test 1)
cd terraform/network
terraform init
terraform plan
terraform apply

# Deploy bastion (Test 2-3)
cd ../bastion
terraform apply

# Verify netboot infrastructure (Test 3)
ssh ubuntu@10.20.13.140 "docker ps"

# Launch Talos node (Test 4)
# (Manual for now, see docs/BOOTSTRAP.md)
```

### Bootstrap CozyStack

```bash
# Get talos config
talosctl -n 10.20.13.x config

# Bootstrap cluster
talosctl -n 10.20.13.x bootstrap

# Install CozyStack
# (See docs/COZYSTACK.md for detailed steps)
```

---

## 🎓 What You'll Learn

This project demonstrates:

- ✨ **Hybrid Cloud Economics** - When cloud makes sense vs. home lab
- 🏗️ **Infrastructure Replication** - Exact topology in AWS and home
- 🔧 **ARM64 Validation** - Test before bare-metal deployment
- 🌐 **Network Architecture** - Private-first, GDPR-safe design
- 📦 **Custom Talos Images** - Extensions for Spin + Tailscale
- 🔄 **GitOps with Flux** - Including new ExternalArtifact features
- 💰 **Cost Optimization** - Free tier strategies and monitoring
- 🧪 **TDG Methodology** - Test-driven infrastructure generation

---

## 🏆 Success Metrics

### Event Day (May 26)
- [ ] Tests 1-6 passing (Network → Demo workload)
- [ ] Live netboot < 5 minutes
- [ ] SpinKube demo runs on ARM64
- [ ] Cost stays under $0.10/month
- [ ] Audience can replicate in their own AWS account

### Post-Event
- [ ] Home lab transitions to Raspberry Pi CM3 modules
- [ ] Office temperature drops 15°F
- [ ] Power bill decreases measurably
- [ ] Wife's approval rating improves 📈

---

## 👥 Credits

**Speaker**: [Kingdon Barrett](https://github.com/kingdonb)  
*Flux Maintainer, DevOps Engineer at Navteca, LLC*  
*Working on Science Cloud for NASA Goddard Space Flight Center*

**Methodology**: [Chanwit Kaewkasi](https://github.com/chanwit)  
*TDG Innovator*

**Platform**: [Andrei Kvapil](https://github.com/kvaps)  
*CozyStack Creator*

**Built with**:
- 🤖 [Claude](https://claude.ai) (Anthropic) - Infrastructure design & TDG implementation
- 🧰 [CozyStack](https://cozystack.io) - Kubernetes platform for bare metal
- 🐧 [Talos Linux](https://www.talos.dev) - Immutable Kubernetes OS
- ☁️ [AWS](https://aws.amazon.com) - Free tier cloud validation
- 🔄 [Flux](https://fluxcd.io) - GitOps toolkit
- 🏃 [SpinKube](https://spinkube.dev) - WebAssembly on Kubernetes

---

## 📅 Timeline

| Date | Milestone |
|------|-----------|
| Nov 16 | 🎬 Project kickoff, TDG tests defined |
| Nov 23 | 🏗️ Network foundation + bastion deployed |
| Nov 30 | 🐧 First Talos node netboots successfully |
| Dec 3 | 🎤 Live demo at CozySummit Virtual 2025 |
| Dec 31 | 🏠 Home lab transitions to Raspberry Pi |

**Free tier expires**: December 2025 (t4g instances)

---

## 🤝 Contributing

This is a conference talk demo, but if you want to replicate or improve:

1. **Follow TDG** - Write tests first
2. **Reference, don't duplicate** - Reuse existing repos
3. **Document your journey** - Others can learn from your experience
4. **Share costs** - Transparency helps everyone

Open issues for questions, PRs for improvements!

---

## 📜 License

Apache 2.0 - See [LICENSE](LICENSE) for details.

---

## 🔗 Links

- 🎤 [CozySummit Virtual 2025](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/)
- 📺 [YouTube: @yebyen/streams](https://youtube.com/@yebyen/streams)
- 🐦 [Follow updates on Twitter](#) *(add your handle)*
- 💬 [Join CozyStack Community](#) *(add Discord/Slack)*

---

<div align="center">

**"It's 2025 - If you're running a cluster, why not host it in the cloud first?"**

🌙 → ☁️ → 🏠 → 🥧

*From basement to cloud and back to Raspberry Pi*

</div>
