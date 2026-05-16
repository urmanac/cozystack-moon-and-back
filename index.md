---
layout: home
title: "CozyStack"
---

# 🚀 Home Lab to the Moon and Back

> **Validating ARM64 Kubernetes in the cloud before committing to bare-metal hardware**

[![CozySummit Virtual 2026](https://img.shields.io/badge/CozySummit-May%2026%2C%202026-blue)](https://community2.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2026/)
[![Built with TDG](https://img.shields.io/badge/built%20with-TDG-purple)](docs/ADRs/ADR-002-TDG-METHODOLOGY.html)
[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-green)](https://urmanac.github.io/cozystack-moon-and-back/)

---

## 🎯 Mission

Transform a **128°F office space heater** into an **ARM64-first cloud deployment**:

- ✅ **Talos Linux** with WebAssembly + Tailscale subnet router
- ✅ **AWS validation** before hardware purchase  
- ✅ **Budget-conscious**: <$0.10/month baseline, <$15/month testing
- ✅ **Live demo** at CozySummit Virtual 2026 (May 26)

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

**⚠️ Pre-Event Validation Phase**

This project is under active validation for CozySummit Virtual 2026 (May 26). A complete quick start guide will be available after the event.

### Available Now

**Custom ARM64 Talos Images**:
- `ghcr.io/urmanac/talos-cozystack-spin-only` - **Compute nodes**: WebAssembly runtime only
- `ghcr.io/urmanac/talos-cozystack-spin-tailscale` - **Gateway nodes**: WebAssembly + Tailscale subnet router

These role-based OCI images solve cluster formation issues by preventing Tailscale configuration conflicts.

These are pure "matchbox" and "talos" OCI images compatible with:
- Docker/Podman for local testing
- [`talm`](https://github.com/cozystack/talm) (Helm-like for Talos Linux)  
- `talos-bootstrap` from CozyStack project

### Development Validation

```bash
# Validate build pipeline and patches
./validate-complete.sh
./validate-patch.sh
```

**Full deployment guide coming post-event** 🎯

---

## 🎯 Project Status

**✅ Completed (November 2025)**:
ARM64 Talos builds, CI/CD pipeline, container images, TDG methodology, ADR documentation

**🎯 Event Goals (May 26, 2026)**:
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

### 🏗️ CozyStack Platform
Our "batteries included" Kubernetes distribution that handles the complexity of cloud-native deployments. CozyStack integrates Helm, Flux, and a comprehensive suite of ARM64-ready cloud-native technologies, providing a complete platform experience. Runs exclusively on Talos Linux for maximum simplicity and reliability.

### 🐧 Talos Linux Foundation
The immutable, API-driven container OS that serves as CozyStack's foundation. Talos's simplicity and robust ARM64 support make it the natural choice for this architecture. Our custom Talos images include WebAssembly and Tailscale extensions, demonstrating practical extension building patterns for specialized deployments.

### ⚡ WebAssembly (Spin) Runtime
The answer to "what happens when you lose fancy virtualization on Raspberry Pi?" WebAssembly enables **serverless patterns that scale to zero**, driving costs down while WASM's sandbox acts as a forcing function against complex Rube Goldberg architectures. This is **microservices done right** - better composability, system simplicity, and well-defined interfaces. WASM's sandboxed nature aligns perfectly with Talos's isolated/immutable design.

### ☁️ AWS Graviton Validation
Cloud-first validation using ARM64 Graviton instances provides access to advanced CPU features and virtualization extensions to exceed home lab capabilities. Enables **apples-to-apples comparisons** and advanced experiments that would otherwise require much >>$500-800 (substantial) hardware investments, through cheap (sometimes free!) cloud hardware. **Cost strategy**: Time-boxed experiments with clear outcomes, aggressive resource cleanup between rounds.

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
