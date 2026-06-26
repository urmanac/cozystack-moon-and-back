---
title: "Documentation"
layout: page
---

# 📚 ARM64 Kubernetes Documentation

Welcome to the comprehensive documentation for the **Home Lab to the Moon and Back** project - validating ARM64 architecture in the cloud before committing to bare-metal hardware.

> 🎯 **Mission**: Develop a cloud-validated, ARM64-first Kubernetes deployment for [CozySummit Virtual 2025](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/) on **December 3, 2025** to replace traditional high-power AMD64 home lab setups.

---

## 🏗️ Architecture Decision Records

📋 **[ADR Index](ADRs/)** - Formal architectural decisions and their rationale

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](ADRs/ADR-001-ARM64-ARCHITECTURE.md) | ARM64 Architecture Choice | ✅ Accepted |
| [ADR-002](ADRs/ADR-002-TDG-METHODOLOGY.md) | Test-Driven Generation Methodology | ✅ Accepted |
| [ADR-003](ADRs/ADR-003-PATCH-GENERATION.md) | Patch Generation Best Practices | ✅ Accepted |
| [ADR-004](ADRs/ADR-004-ROLE-BASED-IMAGES.md) | Role-Based Talos Image Architecture | ✅ Accepted |

---

## 📖 Implementation Guides

🔧 **Step-by-step guides for building and deploying the system**

### Infrastructure Setup
- 📦 **[Custom Talos Images](guides/CUSTOM-TALOS-IMAGES.md)** - Building ARM64 Talos with Spin + Tailscale
- ☁️ **[AWS Infrastructure Handoff](guides/AWS-INFRASTRUCTURE-HANDOFF.md)** - Cloud validation setup
- 🌐 **[Matchbox Server Config](guides/MATCHBOX-SERVER-CONFIG.md)** - Network boot configuration
- 🔥 **[Live Fire Test Instructions](guides/LIVE-FIRE-TEST-INSTRUCTIONS.md)** - End-to-end validation testing

### Development & Testing  
- 🧪 **[TDG Implementation Story](TDG-PLAN.md)** - Test-Driven Generation journey
- 📊 **[Repository Overview](REPO-OVERVIEW.md)** - Project structure and organization

---

## 💰 Cost Analysis & Planning

📈 **Financial planning and cost validation**

- 💵 **[Detailed Cost Analysis](COST-ANALYSIS.md)** - Comprehensive cost breakdown and projections
- 📊 **[Cost Summary](COST.md)** - Quick cost reference and baseline metrics

**Budget Targets:**
- **Baseline**: <$0.10/month (idle infrastructure)  
- **Validation**: <$15/month (active testing periods)
- **Demo**: Efficient resource usage for live presentation

---

## 🚀 Quick Start

### 1. **Validate ARM64 Talos Images**
```bash
# Pull the demo-ready ARM64 image
docker pull ghcr.io/urmanac/talos-cozystack-demo:demo-stable

# Extract boot assets for validation
mkdir -p /tmp/talos-assets
docker create --name temp ghcr.io/urmanac/talos-cozystack-demo:demo-stable true
docker cp temp:/assets/. /tmp/talos-assets/
docker rm temp

# Verify ARM64 Talos files
ls -la /tmp/talos-assets/talos/arm64/
```

### 2. **Run Local Validation**
```bash
# Comprehensive validation suite (6 stages)
./validate-complete.sh

# Individual validations
./validate-patch.sh                    # Patch application
yq eval '.jobs.build-cozystack-talos-arm64' .github/workflows/build-talos-images.yml  # Workflow syntax
```

### 3. **Deploy to AWS (Optional)**
```bash
# See AWS Infrastructure Handoff guide
cd terraform/
terraform init
terraform plan -var="environment=demo"
terraform apply
```

---

## 📊 Project Status

### ✅ **Completed Milestones**
- [x] **Matrix Strategy Success**: Dual ARM64 Talos image variants with role-based architecture
- [x] ARM64 Talos image builds with Spin + Tailscale extensions working in parallel
- [x] GitHub Actions CI/CD pipeline with comprehensive validation and matrix builds
- [x] Container image publishing to GitHub Container Registry with clean tagging
- [x] Test-Driven Generation methodology implementation
- [x] Comprehensive documentation with ADRs

### 🎯 **Working Image Variants**
- **Compute Nodes**: `ghcr.io/urmanac/talos-cozystack-spin-only/talos:v1.11.5`
- **Gateway Nodes**: `ghcr.io/urmanac/talos-cozystack-spin-tailscale/talos:v1.11.5`

### 🔄 **Current Phase: Live Testing**
- [x] GitHub Pages setup with beautiful navigation
- [x] Integration with upstream CozyStack build system  
- [ ] Role-based cluster formation testing
- [ ] Performance benchmarking on AWS t4g instances
- [ ] Cost optimization and monitoring setup

### 🎯 **December 3, 2025 Demo Targets**
- [ ] Live SpinKube demonstration on ARM64
- [ ] Role-based cluster formation showcase
- [ ] Tailscale subnet router demonstration
- [ ] Real-time cost transparency during presentation
- [ ] Home lab transition plan presentation

---

## 🛠️ Development Workflow

### **Test-Driven Generation (TDG) Process**
1. **🔍 Understand** - Analyze requirements and constraints
2. **🧪 Local Validation** - Run complete validation suite
3. **✅ Validate Changes** - Ensure patches apply cleanly  
4. **🚀 Generate Solutions** - Use proper tooling (Git, not manual)
5. **📚 Document Decisions** - Capture knowledge in ADRs

### **Validation Gates**
```bash
# Before any commit
./validate-complete.sh          # 6-stage comprehensive validation

# Before any push  
git apply --check patches/*.patch  # Patch compatibility
yq eval '.jobs' .github/workflows/build-talos-images.yml  # Workflow syntax
```

---

## 🌟 Key Technologies

| Technology | Purpose | ARM64 Status |
|------------|---------|--------------|
| **Talos Linux** | Immutable Kubernetes OS | ✅ Full support |
| **CozyStack** | Kubernetes distribution | 🔄 Custom ARM64 build |
| **Spin** | WebAssembly runtime | ✅ Native ARM64 |
| **Tailscale** | VPC subnet router | ✅ ARM64 optimized |
| **AWS Graviton** | ARM64 cloud validation | ✅ t4g instances |

---

## 📞 Support & Contributing

- **🐛 Issues**: [GitHub Issues](https://github.com/urmanac/cozystack-moon-and-back/issues)
- **💡 Discussions**: [GitHub Discussions](https://github.com/urmanac/cozystack-moon-and-back/discussions)
- **📧 Contact**: [CozySummit Virtual 2025](https://community.cncf.io/events/details/cncf-virtual-project-events-hosted-by-cncf-presents-cozysummit-virtual-2025/)

### **Contributing Guidelines**
1. Follow TDG methodology (see [ADR-002](ADRs/ADR-002-TDG-METHODOLOGY.md))
2. Run local validation before PR submission
3. Document architectural decisions in ADRs
4. Update cost analysis for infrastructure changes

---

## 📋 Meta Documentation

📚 **Project organization and build system documentation**

- 📄 **[About Latest Build](ABOUT-LATEST-BUILD.md)** - Understanding auto-generated build status
- 🏷️ **[Package Naming Cleanup](PACKAGE-NAMING-CLEANUP.md)** - Package naming conventions
- 🔍 **[Package Audit and Release Mapping](PACKAGE-AUDIT-AND-RELEASE-MAPPING.md)** - Audit of GHCR package organization and tagging lifecycle
- 🏷️ **[ROSEMARY-18 Release Notes (v1.5.0-1.13.5-1)](ROSEMARY-18-V1.5.0-1.13.5-1-RELEASE.md)** - Release plan and upgrade notes
- 🏷️ **[SAGE-19 Release Notes (v1.5.1-1.13.5-2)](SAGE-19-V1.5.1-1.13.5-2-RELEASE.md)** - Release plan and upgrade notes

---

## 🏷️ Project Meta

- **License**: Apache 2.0
- **Status**: Active Development (Demo: Dec 3, 2025)
- **Architecture**: ARM64-first with cloud validation
- **Methodology**: Test-Driven Generation (TDG)

---

📍 **Navigation**: [🏠 Project Home](../README.md) | [🏗️ ADRs](ADRs/) | [📖 Guides](guides/)