---
layout: home
title: "Home Lab to the Moon and Back: ARM64 Kubernetes with Spin and Tailscale"
---

# 🚀 Home Lab to the Moon and Back

> **Validating ARM64 CozyStack in the cloud before committing to bare-metal hardware**

[![CozySummit Virtual 2025](https://img.shields.io/badge/CozySummit-Dec%204%2C%202025-blue)](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/)
[![Built with TDG](https://img.shields.io/badge/built%20with-TDG-purple)](docs/ADRs/ADR-002-TDG-METHODOLOGY.html)
[![GitHub Pages](https://img.shields.io/badge/docs-GitHub%20Pages-green)](https://urmanac.github.io/cozystack-moon-and-back/)

---

## 🎯 The Mission

Transform a **76°F office space heater** (aka home lab) into a **cloud-validated, ARM64-first Kubernetes deployment** featuring:

- ✅ **ARM64 Talos Linux** with Spin + Tailscale extensions
- ✅ **AWS t4g validation** before Raspberry Pi hardware purchase  
- ✅ **WebAssembly demonstrations** on cost-efficient ARM64 architecture
- ✅ **Test-Driven Generation** methodology for reliable infrastructure
- ✅ **Budget-conscious approach**: <$0.10/month baseline, <$15/month validation

**Target**: Live demo at [CozySummit Virtual 2025](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/) on **December 4, 2025**

---

## 🏗️ Architecture Decisions

Our key architectural decisions documented in ADRs:

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
</div>

---

## 🚀 Quick Start

### 1. **Get the Custom Talos Images**

```bash
# Pull the demo-ready image
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable

# Extract ARM64 boot assets
mkdir -p /tmp/talos-assets
docker create --name temp ghcr.io/urmanac/talos-cozystack-demo:demo-stable true
docker cp temp:/assets/. /tmp/talos-assets/
docker rm temp

# Verify ARM64 Talos files (kernel + initramfs with extensions)
ls -la /tmp/talos-assets/talos/arm64/
```

### 2. **Validate Locally**

```bash
# Run comprehensive validation (6 stages)
./validate-complete.sh

# Check individual components
./validate-patch.sh                    # Patch compatibility
yq eval '.jobs' .github/workflows/build-talos-images.yml  # Workflow syntax
```

### 3. **Deploy to AWS (Optional)**

Follow our [AWS Infrastructure Guide](docs/guides/AWS-INFRASTRUCTURE-HANDOFF.html) for cloud validation setup.

---

## 📊 Project Status

### ✅ **Completed (November 2025)**
- ARM64 Talos builds with Spin + Tailscale extensions
- Complete CI/CD pipeline with GitHub Actions
- Container images published to GitHub Container Registry
- Test-Driven Generation methodology implementation
- Comprehensive ADR documentation

### 🎯 **Demo Targets (December 4, 2025)**
- Live WebAssembly demonstration on ARM64
- Tailscale mesh networking showcase  
- Real-time cost transparency
- Home lab transition strategy

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

- **[📖 Complete Documentation](docs/)** - Comprehensive guides and references
- **[🏗️ Architecture Decisions](docs/ADRs/)** - Formal ADRs with rationale
- **[🧪 TDG Success Story](docs/TDG-PLAN.html)** - Methodology implementation journey
- **[💵 Cost Planning](docs/COST-ANALYSIS.html)** - Financial analysis and projections

---

## 🌟 Key Technologies

| Technology | Purpose | ARM64 Status |
|------------|---------|--------------|
| **Talos Linux** | Immutable Kubernetes OS | ✅ Full support |
| **CozyStack** | Kubernetes distribution | 🔄 Custom ARM64 build |
| **Spin** | WebAssembly runtime | ✅ Native ARM64 |
| **Tailscale** | Mesh networking | ✅ ARM64 optimized |
| **AWS Graviton** | ARM64 cloud validation | ✅ t4g instances |

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