---
layout: home
title: "Tailscale"
---

# 🚀 Home Lab to the Moon and Back

> **Validating ARM64 Kubernetes in the cloud before committing to bare-metal hardware**

[![CozySummit Virtual 2025](https://img.shields.io/badge/CozySummit-Dec%204%2C%202025-blue)](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/)
[![Built with TDG](https://img.shields.io/badge/built%20with-TDG-purple)](docs/ADRs/ADR-002-TDG-METHODOLOGY.html)
[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-green)](https://urmanac.github.io/cozystack-moon-and-back/)

---

## 🎯 Mission

Transform a **128°F office space heater** into an **ARM64-first cloud deployment**:

- ✅ **Talos Linux** with WebAssembly + Tailscale subnet router
- ✅ **AWS validation** before hardware purchase  
- ✅ **Budget-conscious**: <$0.10/month baseline, <$15/month testing
- ✅ **Live demo** at CozySummit Virtual 2025 (December 4)

---

## 🏗️ Key Decisions

Architectural decisions documented in ADRs:

<div class="architecture-cards">
  <div class="card">
    <h3>🗿 ARM64 Architecture</h3>
    <p>Cloud-first validation before bare-metal investment</p>
    <a href="docs/ADRs/ADR-001-ARM64-ARCHITECTURE.html">ADR-001 →</a>
  </div>
  
  <div class="card">
    <h3>🧪 Test-Driven Generation</h3>
    <p>Systematic validation prevents CI debugging cycles</p>
    <a href="docs/ADRs/ADR-002-TDG-METHODOLOGY.html">ADR-002 →</a>
  </div>
  
  <div class="card">
    <h3>📝 Git-Generated Patches</h3>
    <p>Proper patch generation using Git tools</p>
    <a href="docs/ADRs/ADR-003-PATCH-GENERATION.html">ADR-003 →</a>
  </div>
  
  <div class="card">
    <h3>🏗️ Role-Based Images</h3>
    <p>Separate compute and gateway variants for reliable cluster formation</p>
    <a href="docs/ADRs/ADR-004-ROLE-BASED-IMAGES.html">ADR-004 →</a>
  </div>
</div>

---

## 🚀 Current Status

**⚠️ Pre-Demo Development Phase**

This project is under active development for CozySummit Virtual 2025 (December 4). A complete quick start guide will be available after the demo.

### Available Now

**Custom ARM64 Talos Images**:
- `ghcr.io/urmanac/talos-cozystack-spin-only` - **Compute nodes**: WebAssembly runtime only
- `ghcr.io/urmanac/talos-cozystack-spin-tailscale` - **Gateway nodes**: WebAssembly + Tailscale subnet router

These role-based OCI images solve cluster formation issues by preventing Tailscale configuration conflicts.

These are pure "matchbox" and "talos" OCI images compatible with:
- Docker/Podman for local testing
- `talm` (Talos lifecycle manager)  
- `talos-bootstrap` from CozyStack project

### Development Validation

```bash
# Validate build pipeline and patches
./validate-complete.sh
./validate-patch.sh
```

**Full deployment guide coming post-demo** 🎯

---

## 🎯 Project Status

**✅ Completed (November 2025)**:
ARM64 Talos builds, CI/CD pipeline, container images, TDG methodology, ADR documentation

**🎯 Demo Goals (December 4, 2025)**:
Live WebAssembly demo, VPC subnet router access, cost transparency, home lab transition strategy

---

## 💰 Cost Analysis

| Phase | Monthly Cost | Purpose |
|-------|--------------|---------|
| **Baseline** | <$0.10 | Idle infrastructure monitoring |
| **Validation** | <$15 | Active ARM64 testing on t4g instances |
| **Demo** | Variable | Live presentation resources |

**Smart Validation Strategy**: Test architecture in cloud before $400-800 hardware investment.

[Full Cost Analysis →](docs/COST-ANALYSIS.html)

---

## 🛠️ Development with TDG

Our **Test-Driven Generation** approach replaces trial-and-error with systematic validation:

```
🔍 Understand → 🧪 Test → ✅ Validate → 🚀 Generate → 📚 Document
```

**Results**:
- **Before TDG**: 15+ failed commits, hours of CI debugging
- **After TDG**: 3 clean commits, working solutions

[Learn TDG Methodology →](docs/ADRs/ADR-002-TDG-METHODOLOGY.html)

---

## 📚 Documentation

- **[📖 Complete Documentation](docs/README.html)** - Comprehensive guides and references
- **[🏗️ Architecture Decisions](docs/ADRs/README.html)** - Formal ADRs with rationale
- **[🧪 TDG Success Story](docs/TDG-PLAN.html)** - Methodology implementation journey
- **[💵 Cost Planning](docs/COST-ANALYSIS.html)** - Financial analysis and projections

---

## 🌟 Core Stack

**Talos Linux** · **CozyStack** · **WebAssembly (Spin)** · **Tailscale Subnet Router** · **AWS Graviton**

### 🔌 Tailscale Subnet Router Architecture

Our Tailscale integration runs as a **subnet router** (not mesh) to bridge AWS VPC private networking with home lab access:

- **Single subnet router node**: One Talos node provides VPC access via Tailscale
- **VPC network access**: Connect to AWS private IPv4 networks (`10.20.0.0/16`)  
- **CNI pod network**: Access Kubernetes pod CIDR through existing CNI (Kube-OVN/Cilium)
- **Service network**: Reach MetalLB load balancers in ARP mode within the same VPC
- **Home lab bridge**: Optional second subnet router on bastion host for non-privileged access

This preserves CozyStack's existing CNI while adding secure VPN access to the entire VPC subnet topology.

---

<style>
.architecture-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1rem;
  margin: 2rem 0;
}

.card {
  border: 1px solid #e1e4e8;
  border-radius: 8px;
  padding: 1.5rem;
  background: #f8f9fa;
}

.card h3 {
  margin-top: 0;
  color: #24292e;
}

.card a {
  font-weight: bold;
  text-decoration: none;
}

.card a:hover {
  text-decoration: underline;
}
</style>