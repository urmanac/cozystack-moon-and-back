# Sunkworks Infrastructure Suite

> "Productive Failure" methodology - tests that EXPECT failure and validate recovery

This Terraform suite captures the CozySummit demo success and Sunkworks failure methodology for ongoing ARM64 validation.

## Modules

### 1. Chaos Engineering (`chaos-engineering/`)

AWS Fault Injection Simulator (FIS) experiments for t4g ARM64 instances:

- **Stress Tests**: CPU/memory pressure on t4g.micro (free tier limits!)
- **Network Partition**: Simulate Tailscale subnet router failure between AWS and home lab
- **EBS Failure**: The "ship going down" scenario - EBS failure during Talos etcd writes
- **Instance Termination**: Spot interruption simulation
- **Automated Rollback**: Lambda-triggered recovery when CozyStack bootstrap fails

RTO Target: < 10 minutes

```bash
cd terraform
terraform apply -var-file=episodes/episode-chaos.tfvars
```

### 2. Turing Pi Hardware (`turing-pi/`)

Resource-constrained cluster management:

- **BMC Management**: Terraform provider for Turing Pi 2
- **Talos Configuration**: Optimized for CM4/CM5 with 4GB RAM limits
- **Cost Analysis**: AWS t4g.micro vs Turing Pi ($65/node)
- **Power Monitoring**: Integration with smart plugs
- **Sunkworks Budget Calculator**: When cloud cost exceeds hardware + electricity

```bash
terraform apply -var-file=episodes/episode-failure.tfvars
```

### 3. Stakpak Integration (`stakpak/`)

DevOps automation pipeline:

- **Extension Builds**: Generate Talos extensions (spin + tailscale) from source
- **Upstream Watcher**: Auto-build when CozyStack changes
- **GitOps Bridge**: Stakpak → Flux → CozyStack pipeline
- **Rollback Strategies**: Sunkworks contingency plans

### 4. Live Stream Infrastructure (`live-stream/`)

For future Sunkworks episodes:

- **OBS Automation**: Scene switching via MQTT/Node-RED
- **Cost Overlay**: Real-time AWS spend ("$0.04/month → $15/month" drama)
- **Technical Difficulty**: Automated screen when health checks fail
- **Chat Bot**: Chaos commands (`!sinktheship`, `!networkblip`, `!status`)

## Episode Scenarios

### Success (`episode-success.tfvars`)
- Light chaos, quick recovery
- CozySummit demo mode
- Audience goes home happy

### Failure (`episode-failure.tfvars`)
- Heavy chaos, extended recovery
- The typical Sunkworks experience
- Maximum drama, maximum learning

### Chaos (`episode-chaos.tfvars`)
- Systematic failure injection
- Validated recovery procedures
- Educational content focus

## Quick Start

```bash
# Initialize
cd terraform
terraform init

# Choose your episode
terraform workspace new cozysummit-demo
terraform apply -var-file=episodes/episode-success.tfvars

# Or go full Sunkworks
terraform workspace new sunkworks-chaos
terraform apply -var-file=episodes/episode-chaos.tfvars
```

## Chat Commands (Live Stream)

| Command | Permission | Description |
|---------|------------|-------------|
| `!sinktheship` | Moderator | Full chaos - terminate random node |
| `!networkblip` | Subscriber | Network partition simulation |
| `!stresstest` | Subscriber | CPU stress on cluster |
| `!status` | Everyone | Check cluster health |
| `!rollback` | Moderator | Emergency rollback |
| `!costs` | Everyone | Show AWS burn rate |
| `!drama` | Everyone | Current drama level |

## Cost Analysis

The Sunkworks Budget Calculator answers: **When does cloud cost exceed hardware + electricity?**

```
Hardware Investment:
- Turing Pi 2 Board: $209
- 3x CM4 4GB + NVMe: $300
- Power Supply: $30
- Total: ~$540

Monthly Operating:
- Power: ~$5/month (40W × $0.12/kWh)
- AWS (3x t4g.micro): $18/month post-free-tier

Break-even: ~33 months (if you have cheap electricity)
```

## Directory Structure

```
terraform/
├── main.tf              # Root module orchestration
├── variables.tf         # Root variables
├── chaos-engineering/   # AWS FIS experiments
│   ├── main.tf
│   ├── variables.tf
│   ├── lambda/
│   │   ├── rollback.py
│   │   └── recovery_checker.py
│   └── scenarios/
│       ├── success.tfvars
│       ├── failure.tfvars
│       └── chaos.tfvars
├── turing-pi/           # Hardware management
│   ├── main.tf
│   ├── variables.tf
│   └── templates/
│       ├── talos-cm4.yaml.tpl
│       └── talos-cm5.yaml.tpl
├── stakpak/             # DevOps automation
│   ├── main.tf
│   └── variables.tf
├── live-stream/         # Stream infrastructure
│   ├── main.tf
│   └── variables.tf
└── episodes/            # Episode configurations
    ├── episode-success.tfvars
    ├── episode-failure.tfvars
    └── episode-chaos.tfvars
```

## Philosophy

> Unlike the 128°F office space heater scenario, this infrastructure is designed for **predictable chaos**.

The goal isn't to prevent failure - it's to:
1. Expect failure
2. Inject failure systematically
3. Validate recovery time (RTO < 10 minutes)
4. Learn from each episode

---

*"The ship went down, but we built a better ship." - Sunkworks, Episode TBD*
