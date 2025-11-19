# 🚀 Home Lab to the Moon and Back

> **Validating ARM64 CozyStack in the cloud before committing to bare-metal**  
> *Smart validation strategy: Test first, buy hardware second*

[![CozySummit Virtual 2025](https://img.shields.io/badge/CozySummit-Dec%204%2C%202025-blue)](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Built with TDG](https://img.shields.io/badge/built%20with-TDG-purple)](https://chanwit.medium.com/i-was-wrong-about-test-driven-generation-and-i-couldnt-be-happier-9942b6f09502)

---

## 🎯 The Mission

Transform a **76°F office space heater** (aka home lab) into a **cloud-validated, ARM64-first CozyStack deployment** that:

- ✅ Validates ARM64 architecture on t4g instances before Raspberry Pi purchase
- ✅ Runs experiments within reasonable budget (baseline: $0.08/month, validation: <$15/month)
- ✅ Netboots Talos Linux with custom extensions (Spin + Tailscale)
- ✅ Demonstrates SpinKube on ARM64 in production-like conditions
- ✅ Proves when cloud makes sense vs. efficient home lab hardware
- ✅ Maintains zero GDPR risk (private networking only)

**Target**: Live demo at [CozySummit Virtual 2025](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/) on **December 4, 2025**

---

## 🌡️ The Problem

```
Home Lab Status: 🔥
Office Temperature: 76°F (with AC!)
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

### AWS Cloud (Target)
```
VPC: 10.20.0.0/16 (eu-west-1)
├─ Public Subnet (10.20.1.0/24)
│  └─ NAT Gateway
│
└─ Private Subnet (10.20.13.0/24)
   ├─ Bastion (t4g.small, 5hrs/day)
   │  └─ Docker containers:
   │     ├─ dnsmasq
   │     ├─ matchbox
   │     ├─ registry caches (x5)
   │     └─ pi-hole
   │
   └─ Talos Nodes (t4g.small, on-demand)
      └─ CozyStack on ARM64
         └─ SpinKube demo
```

**Key Innovation**: Exact replica of home lab topology in AWS, staying within free tier limits.

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

### Test Status: 21 Tests Defined

| Phase | Tests | Status |
|-------|-------|--------|
| Network Foundation | 1-3 | ❌ In Progress |
| Bastion & Netboot | 4-6 | ❌ Pending |
| CozyStack Deployment | 7-9 | ❌ Pending |
| Integration Tests | 10-21 | ❌ Pending |

Run tests: `./tests/run-all.sh`

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
| [kingdonb/cozystack-talm-demo](https://github.com/kingdonb/cozystack-talm-demo) | HelmReleases & Speed Runs | 📺 Reference |
| [kingdon-ci/kaniko-builder](https://github.com/kingdon-ci/kaniko-builder) | Custom image builds | 🔧 Tool |
| [kingdon-ci/time-tracker](https://github.com/kingdon-ci/time-tracker) | Session tracking | ⚙️ Optional |
| [kingdonb/mecris](https://github.com/kingdonb/mecris) | MCP server patterns | 🐕 Reference |
| [kingdon-ci/noclaude](https://github.com/kingdon-ci/noclaude) | Self-hosted AI | 🤖 Future |
| [chanwit/tdg](https://github.com/chanwit/tdg) | TDG Methodology | 📖 Methodology |

**See**: [docs/REPO-OVERVIEW.md](docs/REPO-OVERVIEW.md) for full dependency graph.

---

## 🎬 The Demo

### What You'll See (December 4)

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

### Demo Day (December 4)
- [ ] Tests 1-6 passing (Network → Demo workload)
- [ ] Live netboot < 5 minutes
- [ ] SpinKube demo runs on ARM64
- [ ] Cost stays under $0.10/month
- [ ] Audience can replicate in their own AWS account

### Post-Demo
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
| Dec 4 | 🎤 Live demo at CozySummit Virtual 2025 |
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
